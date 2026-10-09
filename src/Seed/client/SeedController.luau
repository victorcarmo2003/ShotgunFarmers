--!strict
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local WeaponSounds = require(ReplicatedStorage.shared.Weapon.WeaponSounds)
local SeedSettings = require(ReplicatedStorage.shared.Seed.SeedSettings)
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
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
	Stages: { Model }?,
	StageScale: number,
}

export type Timer = { Gui: BillboardGui, Anchor: Attachment, Label: TextLabel, Expires: number, Shown: number }

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

local function pop(position: Vector3, stage: number)
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

	WeaponSounds.PlayAt(SeedSettings.GROW_SOUND, position, 1 + (stage - 1) * SeedSettings.GROW_SPEED_STEP)
	task.delay(POP_LIFETIME, function()
		anchor:Destroy()
	end)
end

local function stageModels(name: string): ({ Model }?, number)
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const root = assets and assets:FindFirstChild("SeedStages")
	const folder = root and root:FindFirstChild(name)
	if not folder then
		return nil, 1
	end

	const models: { Model } = {}
	for index = 1, #SeedSettings.GROWTH_STAGES do
		const model = folder:FindFirstChild(tostring(index))
		if not model or not model:IsA("Model") then
			return nil, 1
		end
		models[index] = model
	end

	const scale = folder:GetAttribute("Scale")
	return models, if type(scale) == "number" then scale else 1
end

local function prepare(model: Model): Model
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	return model
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
	self.Timers = {} :: { [BasePart]: Timer }
end

function SeedController:Forget(dirt: BasePart)
	self.Active[dirt] = nil
	self.Finished[dirt] = nil
	const timer = self.Timers[dirt]
	if timer then
		timer.Anchor:Destroy()
		self.Timers[dirt] = nil
	end
end

function SeedController:StartTimer(dirt: BasePart, plant: Model)
	const plantedAt = dirt:GetAttribute("PlantedAt")
	if self.Timers[dirt] or type(plantedAt) ~= "number" then
		return
	end

	const boxCFrame, boxSize = plant:GetBoundingBox()
	const top = boxCFrame.Position.Y + boxSize.Y / 2
	const anchor = Instance.new("Attachment")
	anchor.Name = "SeedTimerAnchor"
	anchor.Parent = dirt
	anchor.WorldPosition = Vector3.new(dirt.Position.X, top + SeedSettings.TIMER_GAP, dirt.Position.Z)

	const size = SeedSettings.TIMER_SIZE
	const gui = Instance.new("BillboardGui")
	gui.Name = "SeedTimer"
	gui.Adornee = anchor
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	gui.MaxDistance = SeedSettings.TIMER_MAX_DISTANCE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	const label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Fonts.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = ""
	label.Parent = gui

	const stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1
	stroke.Parent = label

	gui.Parent = anchor
	self.Timers[dirt] = { Gui = gui, Anchor = anchor, Label = label, Expires = plantedAt + SeedSettings.SEED_LIFETIME, Shown = -1 }
end

function SeedController:StepTimers(now: number)
	for _, timer in self.Timers do
		const remaining = math.max(0, math.ceil(timer.Expires - now))
		if remaining ~= timer.Shown then
			timer.Shown = remaining
			timer.Label.Text = `{remaining}s`
		end
	end
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

	const stages, stageScale = stageModels(gunData.SeedModel)
	const template = if stages then stages[1] else seedTemplate(gunData.SeedModel)
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

	const initialStage = stageAt(workspace:GetServerTimeNow() - plantedAt)
	const shown = if stages then stages[math.max(initialStage, 1)] else template
	const seedInstance = prepare(shown:Clone())
	const surface = dirt.Position + Vector3.yAxis * (width / 2)
	const startCFrame = CFrame.new(surface)
	const endCFrame = CFrame.new(surface + Vector3.new(0, SeedSettings.SEED_RISE_HEIGHT, 0))
	const initialGrowth = if stages then (if initialStage <= 0 then SeedSettings.STAGE_SPROUT_GROWTH else 1)
		else stageGrowth(initialStage)
	seedInstance:PivotTo(startCFrame)
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
		Stages = stages,
		StageScale = stageScale,
	}
	self:ApplyGrowth(self.Active[dirt])

	dirt.Destroying:Once(function()
		self:Forget(dirt)
	end)
end

function SeedController:TargetGrowth(state: SeedState): number
	if state.Stages then
		return if state.Stage <= 0 then SeedSettings.STAGE_SPROUT_GROWTH else 1
	end
	return stageGrowth(state.Stage)
end

function SeedController:AdvanceStage(state: SeedState, stage: number, parent: Instance)
	state.Stage = stage
	const stages = state.Stages
	if stages and stages[stage] then
		state.SeedInstance:Destroy()
		const model = prepare(stages[stage]:Clone())
		model:PivotTo(state.StartCFrame)
		model.Parent = parent
		state.SeedInstance = model
		state.Growth = SeedSettings.STAGE_POP_FROM
		state.Velocity = 0
	end
	pop(state.SeedInstance:GetPivot().Position, stage)
end

function SeedController:ApplyGrowth(state: SeedState)
	const growth = state.Growth
	if state.Stages then
		state.SeedInstance:PivotTo(state.StartCFrame)
		state.SeedInstance:ScaleTo(math.max(state.StageScale * growth, 0.01))
		return
	end
	const rise = math.clamp(growth, 0, 1)
	state.SeedInstance:PivotTo(state.StartCFrame:Lerp(state.EndCFrame, rise))
	state.SeedInstance:ScaleTo(math.max(
		SeedSettings.SEED_START_SCALE + (SeedSettings.SEED_END_SCALE - SeedSettings.SEED_START_SCALE) * growth,
		0.01
	))
end

function SeedController:StepSpring(state: SeedState): boolean
	const target = self:TargetGrowth(state)
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
			self:AdvanceStage(state, stage, dirt)
		end

		const settled = self:StepSpring(state)
		self:ApplyGrowth(state)

		if dirtAlpha >= 1 and state.Stage >= finalStage and settled then
			self.Active[dirt] = nil
			self.Finished[dirt] = true
			self:StartTimer(dirt, state.SeedInstance)
		end
	end

	self:StepTimers(now)
end

SeedController:OnInit(function(self)
	self:Setup()
end)

SeedController:OnStart(function(self)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		const parent = prompt.Parent
		if parent and CollectionService:HasTag(parent, TAG) then
			WeaponSounds.Play2D(SeedSettings.PICKUP_SOUND)
		end
	end)

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
