--!strict
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Ballistics = require(ReplicatedStorage.shared.Weapon.Ballistics)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local HitNet = require(ReplicatedStorage.shared.Hit.Net)
local Throwables = require(ReplicatedStorage.shared.Weapon.Throwables)
local WeaponSounds = require(ReplicatedStorage.shared.Weapon.WeaponSounds)
local WeaponNet = require(ReplicatedStorage.shared.Weapon.Net)
local WeaponVFX = require(ReplicatedStorage.shared.Weapon.WeaponVFX)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Vitals = { Health: number, Armor: number, Stamina: number }

export type Burst = { Emitter: ParticleEmitter, Count: number }

export type BurstPool = { Parts: { BasePart }, Bursts: { [BasePart]: { Burst } }, Next: number }

export type MuzzleRig = { Attachments: { Attachment }, Bursts: { Burst } }

export type PendingShot = {
	GunData: GetGun.GunData,
	Model: Model?,
	Forward: Vector3,
	Direction: Vector3,
	Fallback: Vector3,
	Pellets: { WeaponVFX.Pellet },
	Viewmodel: boolean,
	Flame: boolean,
}

export type Screen = { Part: BasePart, Loops: { ParticleEmitter }, Bursts: { Burst }, ActiveUntil: number, Looping: boolean }

const FOLDER_NAME = "Bullets"
const POOL_SIZE = 10
const BURSTS_PER_FRAME = 14
const MAX_IMPACTS_PER_SHOT = 3
const REMOTE_CULL_DISTANCE = 350
const VIEWMODEL_Z_OFFSET = 1.5
const IMPACT_SURFACE_OFFSET = 0.05
const SCREEN_DEPTH = 2.5
const SCREEN_THICKNESS = 0.1
const SCREEN_BURST_SECONDS = 1.6
const SCREEN_FIRE_START = 12
const HIT_SHAKE = 0.35
const HEAL_FROM_MIN = 1
const TRAIL_FADE_SECONDS = 1.5
const MAX_HEALTH = 100
const RENDER_BIND_NAME = "VFXController_Muzzle"
const RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 3

const remoteParams = RaycastParams.new()
remoteParams.FilterType = Enum.RaycastFilterType.Exclude

const VFXController = Modux.Controller("VFXController", {
	Require = { "ArmsController", "MovementController", "ProjectileController", "SurfaceUIController" },
	Priority = 470,
})

function VFXController:Setup()
	self.Pools = {} :: { [string]: BurstPool }
	self.Muzzles = setmetatable({}, { __mode = "k" }) :: any
	self.Screens = {} :: { [string]: Screen }
	self.Pending = {} :: { PendingShot }
	self.Budget = BURSTS_PER_FRAME :: number
	self.Burning = false :: boolean
end

local function effectsFolder(): Folder
	const existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end

	const folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace
	return folder
end

local function collectBursts(root: Instance, into: { Burst })
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			table.insert(into, { Emitter = descendant, Count = WeaponVFX.EmitCount(descendant) })
		end
	end
end

local function emit(bursts: { Burst })
	for _, burst in bursts do
		burst.Emitter:Emit(burst.Count)
	end
end

local function inert(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
end

local function playerByGameID(id: number): Player?
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("GameID") == id then
			return player
		end
	end

	return nil
end

local function surfaceFrame(position: Vector3, normal: Vector3): CFrame
	const up = if normal.Magnitude > 0.001 then normal.Unit else Vector3.yAxis
	const reference = if math.abs(up.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	const right = up:Cross(reference).Unit
	const back = right:Cross(up).Unit
	return CFrame.fromMatrix(position + up * IMPACT_SURFACE_OFFSET, right, up, back)
end

local function cameraNear(position: Vector3): boolean
	const camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= REMOTE_CULL_DISTANCE
end

function VFXController:Spend(): boolean
	if self.Budget <= 0 then
		return false
	end

	self.Budget -= 1
	return true
end

function VFXController:PoolFor(name: string): BurstPool?
	const existing = self.Pools[name]
	if existing then
		return existing
	end

	if not WeaponVFX.Template(name) then
		return nil
	end

	const pool: BurstPool = { Parts = {}, Bursts = {}, Next = 0 }
	self.Pools[name] = pool
	return pool
end

function VFXController:BurstAt(name: string, frame: CFrame)
	const pool = self:PoolFor(name)
	if not pool or not self:Spend() then
		return
	end

	pool.Next = pool.Next % POOL_SIZE + 1
	local part = pool.Parts[pool.Next]
	if not part or not part.Parent then
		const template = WeaponVFX.Template(name)
		if not template then
			return
		end

		const clone = template:Clone()
		inert(clone)
		clone.CFrame = frame
		clone.Parent = effectsFolder()

		const bursts: { Burst } = {}
		collectBursts(clone, bursts)
		pool.Parts[pool.Next] = clone
		pool.Bursts[clone] = bursts
		part = clone
	end

	part.CFrame = frame
	emit(pool.Bursts[part] or {})
end

function VFXController:RigMuzzle(
	model: Model,
	forward: Vector3,
	templateName: string,
	viewmodel: boolean,
	locked: boolean
): MuzzleRig?
	const rigs = self.Muzzles :: { [Model]: { [string]: MuzzleRig } }
	local byName = rigs[model]
	if byName then
		const cached = byName[templateName]
		if cached and #cached.Attachments > 0 and cached.Attachments[1].Parent then
			return cached
		end
	end

	const muzzle = WeaponVFX.Muzzle(model, forward)
	const template = WeaponVFX.Template(templateName)
	if not muzzle or not template then
		return nil
	end

	const rig: MuzzleRig = { Attachments = {}, Bursts = {} }
	for _, child in template:GetChildren() do
		if not child:IsA("Attachment") then
			continue
		end

		const attachment = child:Clone()
		attachment.CFrame = muzzle.Offset * child.CFrame
		attachment.Parent = muzzle.Anchor
		table.insert(rig.Attachments, attachment)

		for _, emitter in attachment:GetChildren() do
			if not emitter:IsA("ParticleEmitter") then
				continue
			end
			emitter.Enabled = false
			emitter.LockedToPart = locked
			if viewmodel then
				emitter.ZOffset += VIEWMODEL_Z_OFFSET
				emitter.LightInfluence = 0
			end
			table.insert(rig.Bursts, { Emitter = emitter, Count = WeaponVFX.EmitCount(emitter) })
		end
	end

	if not byName then
		const created: { [string]: MuzzleRig } = {}
		byName = created
		rigs[model] = created
	end
	byName[templateName] = rig
	return rig
end

function VFXController:EmitMuzzle(model: Model?, forward: Vector3, templateName: string?, viewmodel: boolean)
	if not model or not templateName then
		return
	end

	const rig = self:RigMuzzle(model, forward, templateName, viewmodel, true)
	if rig then
		emit(rig.Bursts)
	end
end

function VFXController:MuzzleOrigin(model: Model?, forward: Vector3, fallback: Vector3): Vector3
	const frame = if model then WeaponVFX.MuzzleCFrame(model, forward) else nil
	return if frame then frame.Position else fallback
end

function VFXController:Impact(set: WeaponVFX.Set, pellet: WeaponVFX.Pellet)
	if pellet.Kind == "None" then
		return
	end

	const frame = surfaceFrame(pellet.EndPos, pellet.Normal)
	if pellet.Kind == "Head" then
		self:BurstAt(WeaponVFX.IMPACT_HEADSHOT, frame)
	elseif pellet.Kind == "Player" then
		self:BurstAt(WeaponVFX.IMPACT_PLAYER, frame)
	else
		self:BurstAt(set.Impact, frame)
	end
end

function VFXController:PlayShot(
	gunData: GetGun.GunData,
	model: Model?,
	forward: Vector3,
	start: Vector3,
	pellets: { WeaponVFX.Pellet },
	viewmodel: boolean
)
	const set = WeaponVFX.For(gunData.DisplayName)
	if gunData.FireMode ~= "Melee" then
		self:EmitMuzzle(model, forward, set.Muzzle, viewmodel)
	end

	const speed = Ballistics.Speed(gunData)
	local impacts = 0
	for _, pellet in pellets do
		if gunData.FireMode == "Hitscan" then
			self.Dependencies.ProjectileController:Shoot(start, pellet.EndPos, set.Tracer, speed)
		end

		if impacts < MAX_IMPACTS_PER_SHOT and pellet.Kind ~= "None" then
			impacts += 1
			const delay = pellet.Delay or 0
			if delay > 0 then
				task.delay(delay, function()
					self:Impact(set, pellet)
				end)
			else
				self:Impact(set, pellet)
			end
		end
	end
end

function VFXController:PlayFlame(gunData: GetGun.GunData, model: Model?, origin: Vector3, forward: Vector3, viewmodel: boolean)
	const set = WeaponVFX.For(gunData.DisplayName)
	const rig = if model and set.Flame then self:RigMuzzle(model, forward, set.Flame, viewmodel, false) else nil
	if not rig then
		self.Dependencies.ProjectileController:Flame(origin, forward, gunData.Range, gunData.Spread)
		return
	end

	for _, attachment in rig.Attachments do
		attachment.WorldCFrame = CFrame.lookAt(attachment.WorldPosition, attachment.WorldPosition + forward)
	end
	emit(rig.Bursts)
end

local function remoteVisual(character: Model, gunData: GetGun.GunData): Model?
	const visual = character:FindFirstChild(gunData.DisplayName)
	return if visual and visual:IsA("Model") then visual else nil
end

function VFXController:Queue(shot: PendingShot)
	table.insert(self.Pending, shot)
end

function VFXController:FlushShots()
	const pending = self.Pending :: { PendingShot }
	if #pending == 0 then
		return
	end

	for _, shot in pending do
		const model = if shot.Model and shot.Model.Parent then shot.Model else nil
		const origin = self:MuzzleOrigin(model, shot.Forward, shot.Fallback)
		if shot.Flame then
			self:PlayFlame(shot.GunData, model, origin, shot.Direction, shot.Viewmodel)
		else
			self:PlayShot(shot.GunData, model, shot.Forward, origin, shot.Pellets, shot.Viewmodel)
		end
	end
	table.clear(pending)
end

function VFXController:LocalModel(gunData: GetGun.GunData): (Model?, boolean)
	const weaponModel = self.Dependencies.ArmsController.WeaponModel
	if weaponModel and weaponModel.Parent then
		return weaponModel, true
	end

	const character = self.Dependencies.MovementController.Character
	return if character then remoteVisual(character, gunData) else nil, false
end

function VFXController:LocalShot(gunData: GetGun.GunData, forward: Vector3, start: Vector3, pellets: { WeaponVFX.Pellet })
	const model, viewmodel = self:LocalModel(gunData)
	self:Queue({
		GunData = gunData,
		Model = model,
		Forward = forward,
		Direction = forward,
		Fallback = start,
		Pellets = pellets,
		Viewmodel = viewmodel,
		Flame = false,
	})
end

function VFXController:LocalFlame(gunData: GetGun.GunData, origin: Vector3, forward: Vector3)
	const model, viewmodel = self:LocalModel(gunData)
	self:Queue({
		GunData = gunData,
		Model = model,
		Forward = forward,
		Direction = forward,
		Fallback = origin,
		Pellets = {},
		Viewmodel = viewmodel,
		Flame = true,
	})
end

local function spreadDirection(direction: Vector3, spread: number): Vector3
	if spread <= 0 then
		return direction
	end

	const angleX = math.rad((math.random() - 0.5) * 2 * spread)
	const angleY = math.rad((math.random() - 0.5) * 2 * spread)
	return (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(angleX, angleY, 0)).LookVector
end

local function kindOf(result: RaycastResult): WeaponVFX.PelletKind
	const model = result.Instance:FindFirstAncestorOfClass("Model")
	if model and Players:GetPlayerFromCharacter(model) then
		return if result.Instance.Name == "Head" then "Head" else "Player"
	end

	return "Wall"
end

function VFXController:OnShotSound(packet: WeaponNet.ShotSound)
	const shooter = playerByGameID(packet.ShooterID)
	const gunData = GetGun.ByID(packet.GunID)
	if not shooter or shooter == Players.LocalPlayer or not gunData then
		return
	end

	const soundName = WeaponSounds.ShootName(gunData.DisplayName)
	const character = shooter.Character
	if soundName == "" or not character then
		return
	end

	const visual = remoteVisual(character, gunData)
	local parent: Instance? = if visual then visual.PrimaryPart else nil
	if not parent then
		parent = character:FindFirstChild("HumanoidRootPart")
	end
	if parent then
		WeaponSounds.PlayPooled(soundName, parent)
	end
end

function VFXController:OnRemoteShot(packet: HitNet.Shot)
	const shooter = playerByGameID(packet.ShooterID)
	const gunData = GetGun.ByID(packet.GunID)
	if not shooter or shooter == Players.LocalPlayer or not gunData then
		return
	end

	const character = shooter.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not character or not root or not root:IsA("BasePart") or not cameraNear(packet.Origin) then
		return
	end

	const visual = remoteVisual(character, gunData)
	const facing = root.CFrame.LookVector
	const direction = packet.Direction

	if gunData.FireMode == "Cone" then
		self:Queue({
			GunData = gunData,
			Model = visual,
			Forward = direction,
			Direction = direction,
			Fallback = packet.Origin,
			Pellets = {},
			Viewmodel = false,
			Flame = true,
		})
		return
	end

	const ignore: { Instance } = { character }
	const camera = workspace.CurrentCamera
	if camera then
		table.insert(ignore, camera)
	end
	table.insert(ignore, effectsFolder())
	const throwFolder = workspace:FindFirstChild(Throwables.FOLDER_NAME)
	if throwFolder then
		table.insert(ignore, throwFolder)
	end
	remoteParams.FilterDescendantsInstances = ignore

	const pellets: { WeaponVFX.Pellet } = {}
	if gunData.FireMode == "Hitscan" then
		for _ = 1, math.max(gunData.Bullets, 1) do
			const heading = spreadDirection(direction, gunData.Spread)
			const cast = Ballistics.Cast(gunData, packet.Origin, heading, remoteParams)
			const result = cast.Result
			const pellet: WeaponVFX.Pellet = if result
				then { EndPos = result.Position, Normal = result.Normal, Kind = kindOf(result), Delay = cast.Travel }
				else { EndPos = cast.EndPos, Normal = -heading, Kind = "None", Delay = cast.Travel }
			table.insert(pellets, pellet)
		end
	end

	self:Queue({
		GunData = gunData,
		Model = visual,
		Forward = facing,
		Direction = direction,
		Fallback = packet.Origin,
		Pellets = pellets,
		Viewmodel = false,
		Flame = false,
	})
end

function VFXController:OnRemoteLaunch(packet: WeaponNet.ThrowSpawn)
	const gunData = GetGun.ByID(packet.Kind)
	if not gunData or gunData.FireMode ~= "Projectile" then
		return
	end

	const owner = playerByGameID(packet.OwnerID)
	if not owner or owner == Players.LocalPlayer or not cameraNear(packet.Origin) then
		return
	end

	const character = owner.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not character or not root or not root:IsA("BasePart") then
		return
	end

	self:Queue({
		GunData = gunData,
		Model = remoteVisual(character, gunData),
		Forward = root.CFrame.LookVector,
		Direction = root.CFrame.LookVector,
		Fallback = packet.Origin,
		Pellets = {},
		Viewmodel = false,
		Flame = false,
	})
end

function VFXController:AttachTrail(visual: Model, gunName: string)
	const trailName = WeaponVFX.For(gunName).Trail
	const template = if trailName then WeaponVFX.Template(trailName) else nil
	if not template then
		return
	end

	const _, size = visual:GetBoundingBox()
	const trail = template:Clone()
	inert(trail)
	trail.Name = "VFXTrail"
	trail.CFrame = visual:GetPivot() * CFrame.new(0, 0, size.Z * 0.5)
	trail.Parent = visual
end

function VFXController:DetachTrail(visual: Model)
	const trail = visual:FindFirstChild("VFXTrail")
	if not trail or not trail:IsA("BasePart") then
		return
	end

	for _, descendant in trail:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		end
	end

	trail.Parent = effectsFolder()
	Debris:AddItem(trail, TRAIL_FADE_SECONDS)
end

function VFXController:ScreenFor(name: string): Screen?
	const existing = self.Screens[name]
	if existing and existing.Part.Parent then
		return existing
	end

	const template = WeaponVFX.Template(name)
	const camera = workspace.CurrentCamera
	if not template or not camera then
		return nil
	end

	const part = template:Clone()
	inert(part)

	const screen: Screen = { Part = part, Loops = {}, Bursts = {}, ActiveUntil = 0, Looping = false }
	for _, descendant in part:GetDescendants() do
		if not descendant:IsA("ParticleEmitter") then
			continue
		end

		descendant.LockedToPart = true
		descendant.Enabled = false
		if descendant:GetAttribute(WeaponVFX.LOOP_ATTRIBUTE) == true then
			table.insert(screen.Loops, descendant)
		else
			table.insert(screen.Bursts, { Emitter = descendant, Count = WeaponVFX.EmitCount(descendant) })
		end
	end

	part.Parent = camera
	self.Screens[name] = screen
	return screen
end

function VFXController:PlaceScreen(screen: Screen, camera: Camera)
	const height = 2 * SCREEN_DEPTH * math.tan(math.rad(camera.FieldOfView) * 0.5)
	const viewport = camera.ViewportSize
	const aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
	screen.Part.Size = Vector3.new(height * aspect, height, SCREEN_THICKNESS)
	screen.Part.CFrame = camera.CFrame * CFrame.new(0, 0, -SCREEN_DEPTH)
end

function VFXController:ScreenBurst(name: string)
	const screen = self:ScreenFor(name)
	const camera = workspace.CurrentCamera
	if not screen or not camera then
		return
	end

	self:PlaceScreen(screen, camera)
	screen.ActiveUntil = math.max(screen.ActiveUntil, os.clock() + SCREEN_BURST_SECONDS)
	emit(screen.Bursts)
end

function VFXController:SetBurning(burning: boolean)
	if self.Burning == burning then
		return
	end
	self.Burning = burning

	const screen = self:ScreenFor(WeaponVFX.SCREEN_FIRE)
	if not screen then
		return
	end

	screen.Looping = burning
	for _, emitter in screen.Loops do
		emitter.Enabled = burning
	end

	if burning then
		const camera = workspace.CurrentCamera
		if camera then
			self:PlaceScreen(screen, camera)
		end
		for _, burst in screen.Bursts do
			burst.Emitter:Emit(math.max(burst.Count, SCREEN_FIRE_START))
		end
	end
	screen.ActiveUntil = os.clock() + SCREEN_BURST_SECONDS
end

function VFXController:StepScreens()
	const camera = workspace.CurrentCamera
	if not camera then
		return
	end

	const now = os.clock()
	for _, screen in self.Screens do
		if screen.Looping or now < screen.ActiveUntil then
			if screen.Part.Parent ~= camera then
				screen.Part.Parent = camera
			end
			self:PlaceScreen(screen, camera)
		end
	end
end

function VFXController:HealBurst(player: Player)
	const character = player.Character
	const torso = if character then (character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")) else nil
	if not torso or not torso:IsA("BasePart") or not cameraNear(torso.Position) then
		return
	end

	self:BurstAt(WeaponVFX.HEAL_BODY, torso.CFrame)
end

function VFXController:OnVitals(userId: number, record: Vitals, previous: Vitals?)
	if not previous then
		return
	end

	const player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end

	const healed = previous.Health >= HEAL_FROM_MIN and previous.Health < MAX_HEALTH and record.Health >= MAX_HEALTH
	if healed then
		self:HealBurst(player)
	end

	if player ~= Players.LocalPlayer then
		return
	end

	if healed then
		self:ScreenBurst(WeaponVFX.SCREEN_HEAL)
	end

	const lost = (previous.Health + previous.Armor) - (record.Health + record.Armor)
	if lost >= WeaponVFX.HEAVY_DAMAGE then
		self:ScreenBurst(WeaponVFX.SCREEN_HIT)
		self.Dependencies.SurfaceUIController:ShakeAll(HIT_SHAKE)
	end
end

function VFXController:WatchBurning()
	const player = Players.LocalPlayer
	const sync = function()
		self:SetBurning(player:GetAttribute(WeaponVFX.BURNING_ATTRIBUTE) == true)
	end

	player:GetAttributeChangedSignal(WeaponVFX.BURNING_ATTRIBUTE):Connect(sync)
	sync()
end

VFXController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Hit.Shot:onClient(function(packet)
		self:OnRemoteShot(packet)
	end)

	self.Libs.Net.Weapon.ThrowSpawn:onClient(function(packet)
		self:OnRemoteLaunch(packet)
	end)

	self.Libs.Net.Weapon.ShotSound:onClient(function(packet)
		self:OnShotSound(packet)
	end)

	self.Libs.Net.Vital.Vitals:onChanged(function(userId, record, previous)
		self:OnVitals(userId, record, previous)
	end)
end)

VFXController:OnStart(function(self)
	self:WatchBurning()

	RunService.Heartbeat:Connect(function()
		self.Budget = BURSTS_PER_FRAME
	end)

	RunService:BindToRenderStep(RENDER_BIND_NAME, RENDER_PRIORITY, function()
		self:FlushShots()
		self:StepScreens()
	end)
end)

return VFXController
