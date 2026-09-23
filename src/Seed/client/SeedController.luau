--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local SeedSettings = require(ReplicatedStorage.shared.Seed.SeedSettings)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const TAG = "Seed"

const TICK_RATE = 60

export type SeedState = {
	SeedInstance: Model,
	PlantedAt: number,
	StartDirtSize: Vector3,
	EndDirtSize: Vector3,
	StartCFrame: CFrame,
	EndCFrame: CFrame,
}

const SeedController = Modux.Controller("SeedController", { Priority = 400 })

local function seedTemplate(name: string): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const seeds = assets and assets:FindFirstChild("Seeds")
	const template = seeds and seeds:FindFirstChild(name)
	if template and template:IsA("Model") then
		return template
	end

	return nil
end

function SeedController:Setup()
	self.Active = {} :: { [BasePart]: SeedState }
	self.Finished = {} :: { [BasePart]: boolean }
end

function SeedController:Forget(dirt: BasePart)
	self.Active[dirt] = nil
	self.Finished[dirt] = nil
end

function SeedController:Render(dirt: BasePart)
	if self.Active[dirt] or self.Finished[dirt] then
		return
	end

	const gunName = dirt:GetAttribute("GunName")
	const plantedAt = dirt:GetAttribute("PlantedAt")
	const gunData = if type(gunName) == "string" then GetGun.ByName(gunName) else nil
	if not gunData or type(plantedAt) ~= "number" then
		warn(`[SeedController] semente sem GunName/PlantedAt valido em {dirt:GetFullName()}`)
		return
	end

	const template = seedTemplate(gunData.SeedModel)
	if not template then
		warn(`[SeedController] SeedModel "{gunData.SeedModel}" nao esta em ReplicatedStorage.Assets.Seeds`)
		return
	end

	const width = dirt.Size.X
	const startDirtSize = Vector3.new(width, SeedSettings.DIRT_START_DIAMETER, SeedSettings.DIRT_START_DIAMETER)
	const endDirtSize = Vector3.new(width, SeedSettings.DIRT_END_DIAMETER, SeedSettings.DIRT_END_DIAMETER)
	dirt.Size = startDirtSize

	const seedInstance = template:Clone() :: Model
	const startCFrame = CFrame.new(dirt.Position)
	const endCFrame = CFrame.new(dirt.Position + Vector3.new(0, SeedSettings.SEED_RISE_HEIGHT, 0))
	seedInstance:PivotTo(startCFrame)
	seedInstance:ScaleTo(SeedSettings.SEED_START_SCALE)
	seedInstance.Parent = dirt

	self.Active[dirt] = {
		SeedInstance = seedInstance,
		PlantedAt = plantedAt,
		StartDirtSize = startDirtSize,
		EndDirtSize = endDirtSize,
		StartCFrame = startCFrame,
		EndCFrame = endCFrame,
	}

	dirt.Destroying:Once(function()
		self:Forget(dirt)
	end)
end

function SeedController:Step()
	const now = workspace:GetServerTimeNow()
	for dirt, state in self.Active do
		const elapsed = now - state.PlantedAt

		const dirtAlpha = math.clamp(elapsed / SeedSettings.DIRT_GROW_TIME, 0, 1)
		dirt.Size = state.StartDirtSize:Lerp(state.EndDirtSize, dirtAlpha)

		const seedAlpha = math.clamp(elapsed / SeedSettings.SEED_GROW_TIME, 0, 1)
		state.SeedInstance:PivotTo(state.StartCFrame:Lerp(state.EndCFrame, seedAlpha))
		state.SeedInstance:ScaleTo(
			SeedSettings.SEED_START_SCALE
				+ (SeedSettings.SEED_END_SCALE - SeedSettings.SEED_START_SCALE) * seedAlpha
		)

		if dirtAlpha >= 1 and seedAlpha >= 1 then
			self.Active[dirt] = nil
			self.Finished[dirt] = true
		end
	end
end

SeedController:OnInit(function(self)
	self:Setup()
end)

SeedController:OnStart(function(self)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance: Instance)
		if instance:IsA("BasePart") then
			self:Render(instance)
		end
	end)

	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance: Instance)
		if instance:IsA("BasePart") then
			self:Forget(instance)
		end
	end)

	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:IsA("BasePart") then
			self:Render(instance)
		end
	end
end)

SeedController:OnTick(function(self)
	self:Step()
end, TICK_RATE)

return SeedController
