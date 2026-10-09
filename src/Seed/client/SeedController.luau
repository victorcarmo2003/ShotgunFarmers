--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local WeaponSounds = require(ReplicatedStorage.shared.Weapon.WeaponSounds)
local SeedSettings = require(ReplicatedStorage.shared.Seed.SeedSettings)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const TAG = "Seed"

const TICK_RATE = 60
const STEP = 1 / TICK_RATE
const POP_LIFETIME = 1.2
const POP_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

export type SeedState = {
	SeedInstance: Model,
	PlantedAt: number,
	StartDirtSize: Vector3,
	EndDirtSize: Vector3,
	StartCFrame: CFrame,
	EndCFrame: CFrame,
	Stage: number,
	Growth: number,
	Velocity: number,
}

const SeedController = Modux.Controller("SeedController", { Priority = 400 })

const warnedTemplates: { [string]: boolean } = {}

local function stageAt(elapsed: number): number
	const stages = SeedSettings.GROWTH_STAGES
	const interval = SeedSettings.SEED_GROW_TIME / #stages
	return math.clamp(math.floor(elapsed / interval), 0, #stages)
end

local function stageGrowth(stage: number): number
	return if stage <= 0 then 0 else SeedSettings.GROWTH_STAGES[stage]
end

local function pop(position: Vector3)
	const anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain

	const emitter = Instance.new("ParticleEmitter")
	emitter.Texture = POP_TEXTURE
	emitter.Color = ColorSequence.new(SeedSettings.POP_COLOR)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 4, 0)
	emitter.Drag = 3
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(SeedSettings.POP_PARTICLES)

	WeaponSounds.PlayAt(SeedSettings.GROW_SOUND, position)
	task.delay(POP_LIFETIME, function()
		anchor:Destroy()
	end)
end

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
		if not warnedTemplates[gunData.SeedModel] then
			warnedTemplates[gunData.SeedModel] = true
			warn(`[SeedController] SeedModel "{gunData.SeedModel}" nao esta em ReplicatedStorage.Assets.Seeds`)
		end
		self.Finished[dirt] = true
		return
	end

	const width = dirt.Size.X
	const startDirtSize = Vector3.new(width, SeedSettings.DIRT_START_DIAMETER, SeedSettings.DIRT_START_DIAMETER)
	const endDirtSize = Vector3.new(width, SeedSettings.DIRT_END_DIAMETER, SeedSettings.DIRT_END_DIAMETER)
	dirt.Size = startDirtSize

	const seedInstance = template:Clone() :: Model
	for _, part in seedInstance:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	const startCFrame = CFrame.new(dirt.Position)
	const endCFrame = CFrame.new(dirt.Position + Vector3.new(0, SeedSettings.SEED_RISE_HEIGHT, 0))
	const initialStage = stageAt(workspace:GetServerTimeNow() - plantedAt)
	const initialGrowth = stageGrowth(initialStage)
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
		Stage = initialStage,
		Growth = initialGrowth,
		Velocity = 0,
	}
	self:ApplyGrowth(self.Active[dirt])

	dirt.Destroying:Once(function()
		self:Forget(dirt)
	end)
end

function SeedController:ApplyGrowth(state: SeedState)
	const growth = state.Growth
	const rise = math.clamp(growth, 0, 1)
	state.SeedInstance:PivotTo(state.StartCFrame:Lerp(state.EndCFrame, rise))
	state.SeedInstance:ScaleTo(math.max(
		SeedSettings.SEED_START_SCALE + (SeedSettings.SEED_END_SCALE - SeedSettings.SEED_START_SCALE) * growth,
		0.01
	))
end

function SeedController:StepSpring(state: SeedState): boolean
	const target = stageGrowth(state.Stage)
	const omega = SeedSettings.GROWTH_SPRING_FREQUENCY
	const accel = omega * omega * (target - state.Growth) - 2 * SeedSettings.GROWTH_SPRING_DAMPING * omega * state.Velocity
	state.Velocity += accel * STEP
	state.Growth += state.Velocity * STEP

	const epsilon = SeedSettings.GROWTH_SETTLE_EPSILON
	if math.abs(target - state.Growth) < epsilon and math.abs(state.Velocity) < epsilon then
		state.Growth = target
		state.Velocity = 0
		return true
	end
	return false
end

function SeedController:Step()
	const now = workspace:GetServerTimeNow()
	const finalStage = #SeedSettings.GROWTH_STAGES
	for dirt, state in self.Active do
		const elapsed = now - state.PlantedAt

		const dirtAlpha = math.clamp(elapsed / SeedSettings.DIRT_GROW_TIME, 0, 1)
		dirt.Size = state.StartDirtSize:Lerp(state.EndDirtSize, dirtAlpha)

		const stage = stageAt(elapsed)
		if stage > state.Stage then
			state.Stage = stage
			pop(state.SeedInstance:GetPivot().Position)
		end

		const settled = self:StepSpring(state)
		self:ApplyGrowth(state)

		if dirtAlpha >= 1 and state.Stage >= finalStage and settled then
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
