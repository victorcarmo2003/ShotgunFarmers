local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local GetGun = require(ReplicatedStorage.Shared.Utils.GetGun)
local SeedSettings = require(ReplicatedStorage.Shared.Settings.SeedSettings)

local SeedController = Modux.Controller("SeedController")

local TAG = "SeedComponent"

export type SeedState = {
	Dirt: BasePart,
	SeedInstance: Model?,
	PlantedAt: number,
	StartDirtSize: Vector3,
	EndDirtSize: Vector3,
	StartCFrame: CFrame,
	EndCFrame: CFrame,
}

SeedController.RenderSeed = function(self, dirt: BasePart)
	if self._activeSeeds[dirt] or self._finishedSeeds[dirt] then
		return
	end

	local gunName = dirt:GetAttribute("GunName") :: string?
	local plantedAt = dirt:GetAttribute("PlantedAt") :: number?
	local gunData = gunName and GetGun:GetByName(gunName :: any)

	print(
		`[SeedController] Detectada semente em {dirt:GetFullName()} -- GunName={tostring(gunName)} PlantedAt={tostring(
			plantedAt
		)}`
	)

	if not gunData or not plantedAt then
		warn(
			`[SeedController] Semente sem GunName/PlantedAt válido em {dirt:GetFullName()} -- plantada sem GunMixin.PlantAt?`
		)
		return
	end

	local seedsFolder = ReplicatedStorage:FindFirstChild("Assets")
	seedsFolder = seedsFolder and seedsFolder:FindFirstChild("Seeds")
	local seedTemplate = seedsFolder and seedsFolder:FindFirstChild(gunData.SeedModel)
	if not seedTemplate or not seedTemplate:IsA("Model") then
		warn(`[SeedController] SeedModel "{gunData.SeedModel}" não encontrado em ReplicatedStorage.Assets.Seeds.`)
		return
	end

	local startDirtSize = Vector3.new(dirt.Size.X, SeedSettings.DIRT_START_DIAMETER, SeedSettings.DIRT_START_DIAMETER)
	local endDirtSize = Vector3.new(dirt.Size.X, SeedSettings.DIRT_END_DIAMETER, SeedSettings.DIRT_END_DIAMETER)
	dirt.Size = startDirtSize

	local seedInstance = seedTemplate:Clone() :: Model
	-- Só a POSIÇÃO do dirt, não a rotação dele -- o dirt fica deitado (rotação própria
	-- pra virar mound), mas a semente não deve herdar esse giro, só nascer no mesmo lugar.
	local startCFrame = CFrame.new(dirt.Position)
	local endCFrame = CFrame.new(dirt.Position + Vector3.new(0, SeedSettings.SEED_RISE_HEIGHT, 0))
	seedInstance:PivotTo(startCFrame)
	seedInstance:ScaleTo(SeedSettings.SEED_START_SCALE)
	seedInstance.Parent = dirt

	self._activeSeeds[dirt] = {
		Dirt = dirt,
		SeedInstance = seedInstance,
		PlantedAt = plantedAt,
		StartDirtSize = startDirtSize,
		EndDirtSize = endDirtSize,
		StartCFrame = startCFrame,
		EndCFrame = endCFrame,
	} :: SeedState

	self:Cleanup(dirt.Destroying:Once(function()
		self._activeSeeds[dirt] = nil
		self._finishedSeeds[dirt] = nil
	end))

	print(`[SeedController] Renderizando crescimento de "{gunData.DisplayName}" em {dirt:GetFullName()}`)
end

SeedController.StepSeeds = function(self)
	local now = workspace:GetServerTimeNow()
	for dirt, state in self._activeSeeds do
		local elapsed = now - state.PlantedAt
		local dirtAlpha = math.clamp(elapsed / SeedSettings.DIRT_GROW_TIME, 0, 1)
		dirt.Size = state.StartDirtSize:Lerp(state.EndDirtSize, dirtAlpha)

		local seedAlpha = math.clamp(elapsed / SeedSettings.SEED_GROW_TIME, 0, 1)
		if state.SeedInstance then
			state.SeedInstance:PivotTo(state.StartCFrame:Lerp(state.EndCFrame, seedAlpha))
			local scale = SeedSettings.SEED_START_SCALE
				+ (SeedSettings.SEED_END_SCALE - SeedSettings.SEED_START_SCALE) * seedAlpha
			state.SeedInstance:ScaleTo(scale)
		end

		if dirtAlpha >= 1 and seedAlpha >= 1 then
			self._activeSeeds[dirt] = nil
			self._finishedSeeds[dirt] = true
		end
	end
end

SeedController:OnInit(function(self)
	self._activeSeeds = {} :: { [BasePart]: SeedState }
	self._finishedSeeds = {} :: { [BasePart]: boolean }
end)

SeedController:OnStart(function(self)
	self:Cleanup(CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
		if instance:IsA("BasePart") then
			self:RenderSeed(instance)
		end
	end))

	self:Cleanup(CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		self._activeSeeds[instance] = nil
		self._finishedSeeds[instance] = nil
	end))

	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:IsA("BasePart") then
			self:RenderSeed(instance)
		end
	end

	self:Cleanup(RunService.Heartbeat:Connect(function()
		self:StepSeeds()
	end))
end)

return SeedController
