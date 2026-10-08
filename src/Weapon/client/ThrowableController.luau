--!strict
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local ThrowSim = require(ReplicatedStorage.shared.Weapon.ThrowSim)
local Throwables = require(ReplicatedStorage.shared.Weapon.Throwables)
local WeaponNet = require(ReplicatedStorage.shared.Weapon.Net)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Flight = {
	Id: number,
	Definition: Throwables.Definition,
	Owner: Player?,
	State: ThrowSim.State,
	Params: RaycastParams,
	Visual: Model,
	VisualOffset: Vector3,
	SpinAge: number,
	ExpiresAt: number,
}

export type Button = "Left" | "Right"

export type GasCloud = {
	Spec: Throwables.ZoneSpec,
	Center: Vector3,
	EndsAt: number,
}

const MAX_CATCHUP_STEPS = 30
const ORPHAN_GRACE = 3
const MAX_ORIGIN_FROM_ROOT = 8
const BURST_LIFETIME = 5
const LOOP_BURST_SECONDS = 0.35
const DEFAULT_EMIT = 12
const SHARD_LIFETIME = 0.25
const SHARD_WIDTH = 0.25
const ZONE_FADE_SECONDS = 2.5
const FALLBACK_PROJECTILE_SIZE = 0.9
const FALLBACK_MISSILE_SIZE = Vector3.new(0.7, 0.7, 2.2)
const FALLBACK_ZONE_THICKNESS = 0.4

const PREVIEW_FOLDER_NAME = "ThrowPreview"
const PREVIEW_MAX_STEPS = 360
const PREVIEW_DOT_EVERY = 4
const PREVIEW_DOT_COUNT = 90
const PREVIEW_DOT_SIZE = 0.3
const PREVIEW_MARKER_LIFT = 0.06
const PREVIEW_MARKER_TRANSPARENCY = 0.75
const PREVIEW_DOT_TRANSPARENCY = 0.15
const PREVIEW_MIN_MARKER = 1.5
const VISUAL_BLEND_SECONDS = 0.3
const SPLIT_RELEASE_WINDOW = 0.15
const ARMED_STATES: { [string]: boolean } = {
	Unpinning = true,
	PinIdle = true,
	AimingIn = true,
	AimingOut = true,
	Aim = true,
}
const MAX_VISUAL_OFFSET = 8
const AIM_FALLBACK_RANGE = 500

const BLIND_BLUR = 28
const BLIND_TINT = Color3.fromRGB(205, 225, 160)
const BLIND_BRIGHTNESS = 0.15
const BLIND_CONTRAST = -0.3

const ThrowableController = Modux.Controller("ThrowableController", {
	Require = {
		"ArmsController",
		"GameStateController",
		"InputController",
		"MovementController",
		"VFXController",
		"WeaponController",
	},
	Priority = 460,
})

function ThrowableController:Setup()
	self.Flights = {} :: { [number]: Flight }
	self.GasClouds = {} :: { GasCloud }
	self.Armed = false :: boolean
	self.Queued = false :: boolean
	self.Left = false :: boolean
	self.Right = false :: boolean
	self.PendingMode = Throwables.SHORT_THROW :: number
	self.Consumed = false :: boolean
	self.SplitAt = nil :: number?
	self.LastThrow = 0 :: number
	self.Accumulator = 0 :: number
	self.BlindUntil = 0 :: number
	self.BlindLinger = 1 :: number

	const blur = Instance.new("BlurEffect")
	blur.Name = "ThrowableBlur"
	blur.Size = 0
	blur.Enabled = false
	self.Blur = blur :: BlurEffect

	const tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "ThrowableTint"
	tint.Enabled = false
	self.Tint = tint :: ColorCorrectionEffect

	self.PreviewDots = {} :: { BasePart }
	self.PreviewActive = 0 :: number
	self.PreviewVisible = false :: boolean
	self.PreviewMarker = nil :: BasePart?
	self.PreviewFolder = nil :: Folder?
	self.PreviewParams = ThrowSim.Params() :: RaycastParams
	self.AimParams = ThrowSim.Params() :: RaycastParams
	self.PendingStart = nil :: Vector3?
end

local function effectsFolder(): Folder
	const existing = workspace:FindFirstChild(Throwables.FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end

	const folder = Instance.new("Folder")
	folder.Name = Throwables.FOLDER_NAME
	folder.Parent = workspace
	return folder
end

local function assetFolder(name: string): Instance?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	return if assets then assets:FindFirstChild(name) else nil
end

local function vfxTemplate(name: string): BasePart?
	const folder = assetFolder("VFX")
	const template = if folder then folder:FindFirstChild(name) else nil
	return if template and template:IsA("BasePart") then template else nil
end

local function inertPart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function playSound(name: string, position: Vector3)
	const sounds = assetFolder("Sounds")
	const template = if sounds then sounds:FindFirstChild(name) else nil
	if not template or not template:IsA("Sound") then
		return
	end

	const anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain

	const sound = template:Clone()
	sound.Parent = anchor
	sound:Play()
	Debris:AddItem(anchor, math.max(sound.TimeLength, 1) + 1)
end

local function emitAll(root: Instance)
	for _, descendant in root:GetDescendants() do
		if not descendant:IsA("ParticleEmitter") then
			continue
		end

		if descendant.Enabled then
			task.delay(LOOP_BURST_SECONDS, function()
				descendant.Enabled = false
			end)
			continue
		end

		const count = descendant:GetAttribute("EmitCount")
		const delay = descendant:GetAttribute("EmitDelay")
		const amount = if typeof(count) == "number" then count else DEFAULT_EMIT
		if typeof(delay) == "number" and delay > 0 then
			task.delay(delay, function()
				descendant:Emit(amount)
			end)
		else
			descendant:Emit(amount)
		end
	end
end

local function setEmitters(root: Instance, enabled: boolean)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = enabled
		end
	end
end

local function fallbackBurst(position: Vector3, definition: Throwables.Definition)
	const explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = definition.Radius * 0.5
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.ExplosionType = Enum.ExplosionType.NoCraters
	explosion.Parent = workspace
end

local function playBurst(definition: Throwables.Definition, position: Vector3)
	playSound(definition.Sound, position)
	if definition.ExplosionVisual == "" then
		return
	end

	const template = vfxTemplate(definition.ExplosionVisual)
	if not template then
		fallbackBurst(position, definition)
		return
	end

	const burst = template:Clone()
	inertPart(burst)
	burst.Transparency = 1
	burst.CFrame = CFrame.new(position)
	burst.Parent = effectsFolder()
	emitAll(burst)
	Debris:AddItem(burst, BURST_LIFETIME)
end

local function zoneVisual(spec: Throwables.ZoneSpec, center: Vector3): BasePart
	const template = vfxTemplate(spec.Visual)
	if template then
		const visual = template:Clone()
		inertPart(visual)
		visual.Transparency = 1
		visual.Size = Vector3.new(spec.Radius * 2, math.max(template.Size.Y, 1), spec.Radius * 2)
		visual.CFrame = CFrame.new(center + Vector3.yAxis * visual.Size.Y * 0.5)
		setEmitters(visual, true)
		visual.Parent = effectsFolder()
		return visual
	end

	const disc = Instance.new("Part")
	disc.Name = spec.Visual
	disc.Shape = Enum.PartType.Cylinder
	disc.Material = Enum.Material.Neon
	disc.Color = spec.Color
	disc.Transparency = 0.6
	disc.Size = Vector3.new(FALLBACK_ZONE_THICKNESS, spec.Radius * 2, spec.Radius * 2)
	disc.CFrame = CFrame.new(center + Vector3.yAxis * FALLBACK_ZONE_THICKNESS * 0.5) * CFrame.Angles(0, 0, math.pi / 2)
	inertPart(disc)

	const emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(spec.Color)
	emitter.Rate = spec.Radius * 4
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Speed = NumberRange.new(1, 4)
	emitter.Size = NumberSequence.new(2, 4)
	emitter.Transparency = NumberSequence.new(0.4, 1)
	emitter.EmissionDirection = Enum.NormalId.Right
	emitter.Parent = disc

	disc.Parent = effectsFolder()
	return disc
end

local function playZone(spec: Throwables.ZoneSpec, center: Vector3)
	const visual = zoneVisual(spec, center)
	task.delay(spec.Duration, function()
		setEmitters(visual, false)
		Debris:AddItem(visual, ZONE_FADE_SECONDS)
	end)
end

local function playShards(origin: Vector3, ends: { Vector3 }, color: Color3)
	for _, finish in ends do
		const length = (finish - origin).Magnitude
		if length <= 0 then
			continue
		end

		const streak = Instance.new("Part")
		streak.Name = "Shard"
		streak.Material = Enum.Material.Neon
		streak.Color = color
		streak.Size = Vector3.new(SHARD_WIDTH, SHARD_WIDTH, length)
		streak.CFrame = CFrame.lookAt(origin, finish) * CFrame.new(0, 0, -length * 0.5)
		inertPart(streak)
		streak.Parent = effectsFolder()
		Debris:AddItem(streak, SHARD_LIFETIME)
	end
end

local function playerByGameID(id: number): Player?
	if id <= 0 then
		return nil
	end

	for _, player in Players:GetPlayers() do
		if player:GetAttribute("GameID") == id then
			return player
		end
	end

	return nil
end

local function projectileVisual(definition: Throwables.Definition, gunName: string): Model
	const weapons = assetFolder("Weapons")
	const modelName = definition.ProjectileModel or gunName
	const asset = if weapons then weapons:FindFirstChild(modelName) else nil
	if asset and asset:IsA("Model") then
		const model = asset:Clone()
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				inertPart(descendant)
			elseif descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
				descendant:Destroy()
			end
		end
		model.Parent = effectsFolder()
		return model
	end

	const model = Instance.new("Model")
	model.Name = gunName

	const ball = Instance.new("Part")
	ball.Name = "Root"
	if definition.FaceVelocity then
		ball.Size = FALLBACK_MISSILE_SIZE
		ball.Material = Enum.Material.Neon
	else
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.one * FALLBACK_PROJECTILE_SIZE
		ball.Material = Enum.Material.SmoothPlastic
	end
	ball.Color = definition.Color
	inertPart(ball)
	ball.Parent = model

	model.PrimaryPart = ball
	model.Parent = effectsFolder()
	return model
end

function ThrowableController:IsThrowableEquipped(): boolean
	const gunData = self.Dependencies.WeaponController:GunData()
	return gunData ~= nil and gunData.PoseKind == "Throwable"
end

function ThrowableController:Begin(): boolean
	if not self:IsThrowableEquipped() then
		return false
	end

	const gunData = self.Dependencies.WeaponController:GunData()
	if not gunData or self.Dependencies.WeaponController:ActiveAmmo() <= 0 then
		return false
	end

	if workspace:GetServerTimeNow() - self.LastThrow < gunData.FireRate then
		return false
	end

	const arms = self.Dependencies.ArmsController
	if arms:GetPoseState() ~= "Hold" then
		return false
	end

	arms:BeginThrow()
	self.Armed = arms:GetPoseState() == "Unpinning"
	self.Queued = false
	return self.Armed
end

function ThrowableController:CanUseInput(): boolean
	return self.Dependencies.GameStateController:Can("Combat") and self.Dependencies.InputController.Context ~= "Menu"
end

function ThrowableController:HeldMode(): number
	if self.Left and self.Right then
		return Throwables.MEDIUM_THROW
	end
	return if self.Left then Throwables.LONG_THROW else Throwables.SHORT_THROW
end

function ThrowableController:Press(button: Button): boolean
	if button == "Left" then
		self.Left = true
	else
		self.Right = true
	end
	self.Consumed = false
	self.SplitAt = nil

	if self.Armed then
		return true
	end
	if not self:CanUseInput() then
		return false
	end
	return self:Begin()
end

function ThrowableController:ReleaseButton(button: Button)
	const bothHeld = self.Left and self.Right
	if button == "Left" then
		self.Left = false
	else
		self.Right = false
	end

	if not self.Armed or self.Queued then
		return
	end

	if bothHeld then
		self.SplitAt = os.clock()
		return
	end
	if self.Left or self.Right then
		return
	end

	const splitAt = self.SplitAt
	self.SplitAt = nil
	if splitAt and os.clock() - splitAt <= SPLIT_RELEASE_WINDOW then
		self:Commit(Throwables.MEDIUM_THROW)
	else
		self:Commit(if button == "Left" then Throwables.LONG_THROW else Throwables.SHORT_THROW)
	end
end

function ThrowableController:Commit(mode: number)
	self.PendingMode = mode
	self.Consumed = true
	self.Queued = true
	self:StepStance()
end

function ThrowableController:StepStance()
	const arms = self.Dependencies.ArmsController
	const state = arms:GetPoseState()
	if not state or not ARMED_STATES[state] then
		self.Armed = false
		self.Queued = false
		return
	end

	const short = self:PreviewMode() == Throwables.SHORT_THROW
	const ready: string = if short then "PinIdle" else "Aim"
	if state == ready then
		if self.Queued then
			self:Throw()
		end
	elseif state == "PinIdle" then
		arms:SetThrowStance(true)
	elseif state == "Aim" then
		arms:SetThrowStance(false)
	end
end

function ThrowableController:PreviewMode(): number
	return if self.Queued then self.PendingMode else self:HeldMode()
end

function ThrowableController:PollAim()
	const held = self.Dependencies.ArmsController.AimHeld
	if held == self.Right then
		return
	end

	if not held then
		self:ReleaseButton("Right")
	elseif self:IsThrowableEquipped() then
		self:Press("Right")
	else
		self.Right = true
	end
end

function ThrowableController:ThrowOrigin(): Vector3?
	const movement = self.Dependencies.MovementController
	const character = movement.Character
	const root = if character then character.PrimaryPart else nil
	if not character or not root then
		return nil
	end

	const camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - root.Position).Magnitude <= MAX_ORIGIN_FROM_ROOT then
		return camera.CFrame.Position
	end

	const head = character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head.Position else root.Position
end

function ThrowableController:CurrentDefinition(): Throwables.Definition?
	const gunData = self.Dependencies.WeaponController:GunData()
	return if gunData then Throwables.Get(gunData.DisplayName) else nil
end

function ThrowableController:AimTarget(camera: Camera, definition: Throwables.Definition?): Vector3
	const look = camera.CFrame.LookVector
	const range = if definition and definition.MaxRange then definition.MaxRange else AIM_FALLBACK_RANGE
	const params = self.AimParams
	params.FilterDescendantsInstances = ThrowSim.Ignore(Players.LocalPlayer, true)

	const result = workspace:Raycast(camera.CFrame.Position, look * range, params)
	return if result then result.Position else camera.CFrame.Position + look * range
end

local function blendWeight(age: number): number
	return math.max(1 - age / VISUAL_BLEND_SECONDS, 0)
end

function ThrowableController:VisualStart(): Vector3?
	const arms = self.Dependencies.ArmsController
	if self:IsThrowableEquipped() then
		return arms:GetWeaponRootPosition()
	end
	return arms:GetMuzzlePosition()
end

function ThrowableController:Send(start: Vector3?, mode: number): boolean
	const camera = workspace.CurrentCamera
	const origin = self:ThrowOrigin()
	if not camera or not origin then
		return false
	end

	self.PendingStart = start
	self.LastThrow = workspace:GetServerTimeNow()
	self.Libs.Net.Weapon.Throw:fireServer({
		Origin = origin,
		Direction = camera.CFrame.LookVector,
		Target = self:AimTarget(camera, self:CurrentDefinition()),
		Mode = mode,
		TimeStamp = self.LastThrow,
	})
	return true
end

function ThrowableController:Throw()
	self.Armed = false
	self.Queued = false

	if not self:IsThrowableEquipped() or not self:ThrowOrigin() then
		return
	end

	const arms = self.Dependencies.ArmsController
	const short = self.PendingMode == Throwables.SHORT_THROW
	arms:ReleaseThrow(short)
	self.LastThrow = workspace:GetServerTimeNow()

	task.delay(arms:ThrowReleaseDelay(short), function()
		if not self:IsThrowableEquipped() then
			return
		end

		const start = arms:GetWeaponRootPosition()
		const state = arms:GetPoseState()
		if state == "Throwing" or state == "ThrowingShort" then
			arms:SetWeaponHidden(true)
		end
		self:Send(start, self.PendingMode)
	end)
end

function ThrowableController:Launch(): boolean
	return self:Send(self:VisualStart(), Throwables.LONG_THROW)
end

function ThrowableController:BuildPreview()
	const folder = Instance.new("Folder")
	folder.Name = PREVIEW_FOLDER_NAME
	folder.Parent = workspace
	self.PreviewFolder = folder

	for index = 1, PREVIEW_DOT_COUNT do
		const dot = Instance.new("Part")
		dot.Name = "Dot" .. index
		dot.Shape = Enum.PartType.Ball
		dot.Material = Enum.Material.Neon
		dot.Size = Vector3.one * PREVIEW_DOT_SIZE
		dot.Transparency = PREVIEW_DOT_TRANSPARENCY
		inertPart(dot)
		table.insert(self.PreviewDots, dot)
	end

	const marker = Instance.new("Part")
	marker.Name = "Marker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Material = Enum.Material.Neon
	marker.Transparency = PREVIEW_MARKER_TRANSPARENCY
	inertPart(marker)
	self.PreviewMarker = marker
end

function ThrowableController:HidePreview()
	if not self.PreviewVisible then
		return
	end
	self.PreviewVisible = false

	for index = 1, self.PreviewActive do
		self.PreviewDots[index].Parent = nil
	end
	self.PreviewActive = 0

	const marker = self.PreviewMarker
	if marker then
		marker.Parent = nil
	end
end

function ThrowableController:PreviewDefinition(): Throwables.Definition?
	if not self.Dependencies.GameStateController:Can("Combat") then
		return nil
	end
	if self.Dependencies.InputController.Context == "Menu" then
		return nil
	end
	const weapon = self.Dependencies.WeaponController
	const gunData = weapon:GunData()
	if not gunData or gunData.Disabled then
		return nil
	end

	if gunData.PoseKind == "Throwable" then
		if not self.Armed then
			return nil
		end
	elseif gunData.FireMode ~= "Projectile" or not self.Dependencies.ArmsController.IsAiming() then
		return nil
	end
	if weapon:ActiveAmmo() <= 0 and not self.Armed then
		return nil
	end
	const state = self.Dependencies.ArmsController:GetPoseState()
	if state == "Drawing" or state == "Throwing" or state == "ThrowingShort" then
		return nil
	end

	return Throwables.Get(gunData.DisplayName)
end

function ThrowableController:StepPreview()
	const definition = self:PreviewDefinition()
	const camera = workspace.CurrentCamera
	const origin = if definition then self:ThrowOrigin() else nil
	if not definition or not camera or not origin then
		self:HidePreview()
		return
	end

	if not self.PreviewFolder then
		self:BuildPreview()
	end
	const folder = self.PreviewFolder :: Folder
	const marker = self.PreviewMarker :: BasePart

	const target = self:AimTarget(camera, definition)
	const power = ThrowSim.Power(not self:IsThrowableEquipped(), self:PreviewMode())
	const velocity, curve = ThrowSim.Aim(definition, origin, camera.CFrame.LookVector, target, power)
	const state = ThrowSim.new(origin, velocity, curve)
	const start = self:VisualStart()
	const offset = if start and (start - origin).Magnitude <= MAX_VISUAL_OFFSET then start - origin else Vector3.zero
	const params = self.PreviewParams
	params.FilterDescendantsInstances = ThrowSim.Ignore(Players.LocalPlayer, definition.Contact)

	const maxSteps = math.min(math.ceil(definition.Fuse / Throwables.STEP), PREVIEW_MAX_STEPS)
	local normal = Vector3.yAxis
	local count = 0
	for step = 1, maxSteps do
		const contact = ThrowSim.Step(definition, state, params)
		if contact then
			normal = contact.Normal
			break
		end
		if state.Resting then
			break
		end
		if step % PREVIEW_DOT_EVERY == 0 and count < PREVIEW_DOT_COUNT then
			count += 1
			const dot = self.PreviewDots[count]
			dot.Color = definition.Color
			dot.Position = state.Position + offset * blendWeight(state.Age)
			dot.Parent = folder
		end
	end

	for index = count + 1, self.PreviewActive do
		self.PreviewDots[index].Parent = nil
	end
	self.PreviewActive = count
	self.PreviewVisible = true

	const diameter = math.max(definition.Radius * 2, PREVIEW_MIN_MARKER)
	const position = state.Position + normal * PREVIEW_MARKER_LIFT
	marker.Color = definition.Color
	marker.Size = Vector3.new(PREVIEW_DOT_SIZE * 0.5, diameter, diameter)
	marker.CFrame = CFrame.lookAt(position, position + normal) * CFrame.Angles(0, math.pi / 2, 0)
	marker.Parent = folder
end

function ThrowableController:StepQueue()
	self:PollAim()

	if not self.Left and not self.Right then
		self.Consumed = false
	end

	if not self.Armed then
		if (self.Left or self.Right) and not self.Consumed and self:IsThrowableEquipped() and self:CanUseInput() then
			self:Begin()
		end
		return
	end

	self:StepStance()
end

function ThrowableController:OnSpawn(packet: WeaponNet.ThrowSpawn)
	const gunData = GetGun.ByID(packet.Kind)
	const definition = if gunData then Throwables.Get(gunData.DisplayName) else nil
	if not gunData or not definition then
		return
	end

	const existing = self.Flights[packet.Id]
	if existing then
		existing.Visual:Destroy()
	end

	local visualOffset = Vector3.zero
	const owner = playerByGameID(packet.OwnerID)
	const pending = self.PendingStart
	if owner == Players.LocalPlayer and pending then
		self.PendingStart = nil
		if (pending - packet.Origin).Magnitude <= MAX_VISUAL_OFFSET then
			visualOffset = pending - packet.Origin
		end
	end

	const visual = projectileVisual(definition, gunData.DisplayName)
	self.Dependencies.VFXController:AttachTrail(visual, gunData.DisplayName)
	const flight: Flight = {
		Id = packet.Id,
		Definition = definition,
		Owner = owner,
		State = ThrowSim.new(packet.Origin, packet.Velocity, packet.Curve),
		Params = ThrowSim.Params(),
		Visual = visual,
		VisualOffset = visualOffset,
		SpinAge = 0,
		ExpiresAt = os.clock() + definition.Fuse + ORPHAN_GRACE,
	}
	self.Flights[packet.Id] = flight

	const elapsed = workspace:GetServerTimeNow() - packet.ServerTime
	const catchup = math.clamp(math.floor(elapsed / Throwables.STEP), 0, MAX_CATCHUP_STEPS)
	flight.Params.FilterDescendantsInstances = ThrowSim.Ignore(flight.Owner, definition.Contact)
	for _ = 1, catchup do
		ThrowSim.Step(definition, flight.State, flight.Params)
	end

	self:Render(flight)
end

function ThrowableController:Render(flight: Flight)
	const state = flight.State
	if not state.Resting then
		flight.SpinAge = state.Age
	end
	const position = state.Position + flight.VisualOffset * blendWeight(state.Age)
	if flight.Definition.FaceVelocity and state.Velocity.Magnitude > 0.01 then
		flight.Visual:PivotTo(CFrame.lookAt(position, position + state.Velocity))
		return
	end

	const spin = flight.Definition.Spin * flight.SpinAge
	flight.Visual:PivotTo(CFrame.new(position) * CFrame.Angles(spin.X, spin.Y, spin.Z))
end

function ThrowableController:OnDetonate(packet: WeaponNet.ThrowDetonate)
	const flight = self.Flights[packet.Id]
	if not flight then
		return
	end
	self.Flights[packet.Id] = nil
	self.Dependencies.VFXController:DetachTrail(flight.Visual)
	flight.Visual:Destroy()

	const definition = flight.Definition
	playBurst(definition, packet.Position)
	playShards(packet.Position, packet.Shards, definition.Color)

	const spec = definition.Zone
	if not spec then
		return
	end

	playZone(spec, packet.ZoneCenter)
	if definition.Effect == "Gas" then
		table.insert(self.GasClouds, {
			Spec = spec,
			Center = packet.ZoneCenter,
			EndsAt = os.clock() + spec.Duration,
		})
	end
end

function ThrowableController:ClearAll()
	for _, flight in self.Flights do
		flight.Visual:Destroy()
	end
	table.clear(self.Flights)
	table.clear(self.GasClouds)
	self.BlindUntil = 0

	const folder = workspace:FindFirstChild(Throwables.FOLDER_NAME)
	if folder then
		folder:ClearAllChildren()
	end
end

function ThrowableController:StepFlights(deltaTime: number)
	if next(self.Flights) == nil then
		self.Accumulator = 0
		return
	end

	const now = os.clock()
	self.Accumulator += deltaTime
	while self.Accumulator >= Throwables.STEP do
		self.Accumulator -= Throwables.STEP
		for _, flight in self.Flights do
			if flight.State.Resting then
				continue
			end
			flight.Params.FilterDescendantsInstances = ThrowSim.Ignore(flight.Owner, flight.Definition.Contact)
			ThrowSim.Step(flight.Definition, flight.State, flight.Params)
		end
	end

	for id, flight in self.Flights do
		if now >= flight.ExpiresAt then
			self.Dependencies.VFXController:DetachTrail(flight.Visual)
			flight.Visual:Destroy()
			self.Flights[id] = nil
		else
			self:Render(flight)
		end
	end
end

function ThrowableController:StepBlind()
	const now = os.clock()
	const character = self.Dependencies.MovementController.Character
	const root = if character then character.PrimaryPart else nil

	for index = #self.GasClouds, 1, -1 do
		const cloud = self.GasClouds[index]
		if now >= cloud.EndsAt then
			table.remove(self.GasClouds, index)
		elseif root and Throwables.InsideZone(cloud.Spec, cloud.Center, root.Position) then
			self.BlindUntil = now + cloud.Spec.LingerSeconds
			self.BlindLinger = math.max(cloud.Spec.LingerSeconds, 0.01)
		end
	end

	const intensity = math.clamp((self.BlindUntil - now) / self.BlindLinger, 0, 1)
	const active = intensity > 0
	self.Blur.Enabled = active
	self.Tint.Enabled = active
	if not active then
		return
	end

	self.Blur.Size = BLIND_BLUR * intensity
	self.Tint.TintColor = Color3.new(1, 1, 1):Lerp(BLIND_TINT, intensity)
	self.Tint.Brightness = BLIND_BRIGHTNESS * intensity
	self.Tint.Contrast = BLIND_CONTRAST * intensity
end

ThrowableController:OnInit(function(self)
	self:Setup()
	self.Blur.Parent = Lighting
	self.Tint.Parent = Lighting

	self.Libs.Net.Weapon.ThrowSpawn:onClient(function(packet)
		self:OnSpawn(packet)
	end)

	self.Libs.Net.Weapon.ThrowDetonate:onClient(function(packet)
		self:OnDetonate(packet)
	end)

	self.Libs.Net.Weapon.ThrowClear:onClient(function()
		self:ClearAll()
	end)
end)

ThrowableController:OnStart(function(self)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		self:StepQueue()
		self:StepFlights(deltaTime)
		self:StepBlind()
		self:StepPreview()
	end)
end)

return ThrowableController
