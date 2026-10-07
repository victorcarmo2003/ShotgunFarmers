--!strict
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local GameSettings = require(ReplicatedStorage.shared.Settings.GameSettings)
local GetAnimations = require(ReplicatedStorage.shared.Character.GetAnimations)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WeaponSounds = require(ReplicatedStorage.shared.Weapon.WeaponSounds)
local WeaponVFX = require(ReplicatedStorage.shared.Weapon.WeaponVFX)
local AnimationSetLoader = require(StarterPlayer.StarterPlayerScripts.client.Weapon.AnimationSetLoader)
local PoseMachine = require(StarterPlayer.StarterPlayerScripts.client.Weapon.PoseMachine)
local RigBuilder = require(StarterPlayer.StarterPlayerScripts.client.Character.RigBuilder)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const HIP_OFFSET = CFrame.new(0, -2, -0.796)

const AIM_OFFSET = HIP_OFFSET
const OFFSET_TRANSITION_RATE = 12

const RENDER_BIND_NAME = "ArmsController_Follow"

const CHARACTER_HUMANOID_WAIT_TIMEOUT = 5

const TICK_RATE = 20

const WELD_PART_NAMES: { [GetGun.WeldPart]: string } = {
	RightArm = "Right Arm",
	Torso = "Torso",
}

const PUMP_MARKER_ROLES: { AnimationSetLoader.Role } = { "ShootHip", "ShootAim" }

const DRAW_SOUND_DEBOUNCE = 0.25
const SHOT_AMMO_GRACE = 1.5

const DISCARD_FOLDER = "Discarded"
const DISCARD_LIFETIME = 4
const DISCARD_COLLIDE_DELAY = 0.15
const DISCARD_VELOCITY = Vector3.new(7, 9, -12)
const DISCARD_SPIN = 9

local function hideSurfaceGuis(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("SurfaceGui") then
			descendant.Enabled = false
		end
	end
end

const warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[ArmsController] {message}`)
end

local function weaponAsset(displayName: string): Model?
	const asset = ReplicatedStorage.Assets.Weapons:FindFirstChild(displayName)
	if not asset or not asset:IsA("Model") then
		warnOnce(`asset:{displayName}`, `Assets.Weapons.{displayName} nao existe ou nao e Model; arma fica invisivel no viewmodel`)
		return nil
	end
	return asset
end

local function jointedParts(model: Model): { [BasePart]: boolean }
	const jointed: { [BasePart]: boolean } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			const part0 = descendant.Part0
			const part1 = descendant.Part1
			if part0 then
				jointed[part0] = true
			end
			if part1 then
				jointed[part1] = true
			end
		end
	end
	return jointed
end

local function weldWeapon(rig: Model, weaponModel: Model, gunData: GetGun.GunData)
	const targetPart = rig:FindFirstChild(WELD_PART_NAMES[(gunData.WeldTo or "RightArm") :: GetGun.WeldPart]) :: BasePart?
	const handle = weaponModel.PrimaryPart or (weaponModel:FindFirstChild("Handle", true) :: BasePart?)
	if not targetPart then
		warnOnce(`weldpart:{gunData.DisplayName}`, `rig sem parte {tostring(gunData.WeldTo or "RightArm")} para soldar {gunData.DisplayName}`)
		return
	end
	if not handle then
		warnOnce(`handle:{gunData.DisplayName}`, `{gunData.DisplayName} sem PrimaryPart nem Handle; arma nao e soldada`)
		return
	end

	local armWeld = handle:FindFirstChild("ArmWeld")
	if not armWeld or not armWeld:IsA("Motor6D") then
		warnOnce(`armweld:{gunData.DisplayName}`, `{gunData.DisplayName} sem Motor6D ArmWeld no handle; criado com C0/C1 identidade (arma no centro do braco)`)
		const created = Instance.new("Motor6D")
		created.Name = "ArmWeld"
		created.Parent = handle
		armWeld = created
	end
	const motor = armWeld :: Motor6D
	motor.Part0 = targetPart
	motor.Part1 = handle

	const jointed = jointedParts(weaponModel)
	for _, descendant in weaponModel:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= handle then
			descendant.Anchored = false
			if not jointed[descendant] then
				const safetyWeld = Instance.new("WeldConstraint")
				safetyWeld.Part0 = handle
				safetyWeld.Part1 = descendant
				safetyWeld.Parent = descendant
			end
		end
	end
	handle.Anchored = false
end

const ArmsController = Modux.Controller("ArmsController", {
	Require = { "WeaponController", "MovementController", "InputController", "GameStateController" },
	Priority = 600,
})

function ArmsController:Setup()
	self.Rig = nil :: Model?
	self.Animator = nil :: Animator?
	self.WeaponModel = nil :: Model?
	self.ViewmodelTracks = nil :: AnimationSetLoader.TrackSet?
	self.CharacterAnimator = nil :: Animator?
	self.CharacterTracks = nil :: AnimationSetLoader.TrackSet?
	self.PoseMachine = nil :: PoseMachine.PoseMachine?
	self.PumpMarkerConnections = {} :: { RBXScriptConnection }
	self.CharacterGuiConnection = nil :: RBXScriptConnection?

	self.RiggedCharacter = nil :: Model?
	self.EquippedWeaponID = nil :: number?
	self.EquippedSlot = nil :: number?

	self.IsAiming = Vide.source(false) :: Vide.Source<boolean>
	self.DiscardStarted = false :: boolean
	self.AimHeld = false :: boolean
	self.CurrentOffset = HIP_OFFSET :: CFrame
	self.ViewmodelHidden = false :: boolean
	self.DrawSoundToken = 0 :: number
	self.LastDrawSound = 0 :: number
	self.LastShotAt = 0 :: number
	self.LastShotAmmo = 0 :: number
end

function ArmsController:ClearViewmodel()
	self.DrawSoundToken += 1
	if self.WeaponModel then
		self.WeaponModel:Destroy()
		self.WeaponModel = nil
	end

	for _, connection in self.PumpMarkerConnections do
		connection:Disconnect()
	end
	table.clear(self.PumpMarkerConnections)

	AnimationSetLoader.Unload(self.ViewmodelTracks)
	self.ViewmodelTracks = nil
end

function ArmsController:ClearCharacterPose()
	if self.PoseMachine then
		self.PoseMachine:Destroy()
		self.PoseMachine = nil
	end

	AnimationSetLoader.Unload(self.CharacterTracks)
	self.CharacterTracks = nil
end

function ArmsController:ClearRig()
	self:ClearViewmodel()
	self:ClearCharacterPose()

	if self.Rig then
		self.Rig:Destroy()
		self.Rig = nil
	end

	self.Animator = nil
	self.CharacterAnimator = nil
	self.EquippedWeaponID = nil
	self.EquippedSlot = nil
end

function ArmsController:EquipViewmodel(gunData: GetGun.GunData?)
	self:ClearViewmodel()

	const rig = self.Rig
	if not gunData or not rig then
		return
	end

	const asset = weaponAsset(gunData.DisplayName)
	if asset then
		const weaponModel = asset:Clone()
		for _, descendant in weaponModel:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanQuery = false
			end
		end

		weaponModel.Parent = rig
		self.WeaponModel = weaponModel
		weldWeapon(rig, weaponModel, gunData)
	end

	const animator = self.Animator
	if not animator then
		return
	end

	const tracks = AnimationSetLoader.Load(animator, GetAnimations.Viewmodel(gunData.AnimationSet))
	self.ViewmodelTracks = tracks

	const drawTiming = WeaponSounds.DrawTiming(gunData.DisplayName)
	const marker = if drawTiming then drawTiming.Marker else nil
	if marker then
		for _, track in tracks do
			table.insert(
				self.PumpMarkerConnections,
				track:GetMarkerReachedSignal(marker):Connect(function(parameter: string?)
					if parameter == nil or string.lower(parameter) == "start" then
						self:OnDrawMarker()
					end
				end)
			)
		end
	end

	if gunData.DiscardWhenEmpty then
		for _, role in PUMP_MARKER_ROLES do
			const track = tracks[role]
			if track then
				table.insert(
					self.PumpMarkerConnections,
					track:GetMarkerReachedSignal("Pump"):Connect(function()
						self:OnPumpMarker()
					end)
				)
			end
		end
	end
end

function ArmsController:EquipCharacterPose(gunData: GetGun.GunData?)
	self:ClearCharacterPose()

	const animator = self.CharacterAnimator
	if not gunData or not animator then
		return
	end

	self.CharacterTracks = AnimationSetLoader.Load(animator, GetAnimations.CharacterPose(gunData.DisplayName))

	const poseMachine = PoseMachine.new(self.ViewmodelTracks or {}, self.CharacterTracks or {}, gunData.PoseKind)
	self.PoseMachine = poseMachine
	poseMachine.FSM:OnEnter("Drawing", function()
		self:SetWeaponHidden(self:IsEmptyThrowable())
	end)
	poseMachine.FSM:OnEnter("Hold", function()
		self:SetWeaponHidden(self:IsEmptyThrowable())
	end)
	poseMachine:PlayDraw(self:DrawSeconds(gunData))
	self:ScheduleEquipDrawSound()
end

function ArmsController:DrawSeconds(gunData: GetGun.GunData): number
	const remaining = self.Dependencies.WeaponController.DrawEndsAt() - workspace:GetServerTimeNow()
	if remaining > 0 then
		return remaining
	end

	return gunData.DrawTime or GameSettings.WeaponDrawLock
end

function ArmsController:EquipCurrentGun()
	const weapon = self.Dependencies.WeaponController
	self.EquippedWeaponID = weapon:WeaponID()
	self.EquippedSlot = weapon.ActiveSlot()
	self.DiscardStarted = false

	const gunData = weapon:GunData()
	self:EquipViewmodel(gunData)
	self:EquipCharacterPose(gunData)
	self:SetAiming(self.AimHeld)
	if self.ViewmodelHidden then
		self:ApplyViewmodelHidden()
	end
end

function ArmsController:ApplyViewmodelHidden()
	const rig = self.Rig
	if not rig then
		return
	end

	const value = if self.ViewmodelHidden then 1 else 0
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.LocalTransparencyModifier = value
		end
	end
end

function ArmsController:SetViewmodelHidden(hidden: boolean)
	if self.ViewmodelHidden == hidden then
		return
	end
	self.ViewmodelHidden = hidden
	self:ApplyViewmodelHidden()
	if not hidden then
		self:SetWeaponHidden(self:IsEmptyThrowable())
	end
end

function ArmsController:RebuildRig(character: Model)
	if self.CharacterGuiConnection then
		self.CharacterGuiConnection:Disconnect()
		self.CharacterGuiConnection = nil
	end

	hideSurfaceGuis(character)
	self.CharacterGuiConnection = character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("SurfaceGui") then
			descendant.Enabled = false
		end
	end)

	task.spawn(function()
		const rig, animator = RigBuilder.Build(character)

		if self.RiggedCharacter ~= character then
			if rig then
				rig:Destroy()
			end
			return
		end

		self:ClearRig()
		if not rig then
			return
		end

		rig.Parent = workspace.CurrentCamera
		self.Rig = rig
		self.Animator = animator
		self.CurrentOffset = HIP_OFFSET

		local humanoid = self.Dependencies.MovementController.Humanoid
		if not humanoid then
			humanoid = character:WaitForChild("Humanoid", CHARACTER_HUMANOID_WAIT_TIMEOUT) :: Humanoid?
		end

		const characterAnimator = if humanoid
			then humanoid:WaitForChild("Animator", CHARACTER_HUMANOID_WAIT_TIMEOUT)
			else nil
		self.CharacterAnimator = characterAnimator :: Animator?

		self:EquipCurrentGun()
	end)
end

function ArmsController:SetAiming(requested: boolean)
	self.AimHeld = requested
	const gunData = self.Dependencies.WeaponController:GunData()
	const aiming = requested and not (gunData ~= nil and gunData.PoseKind == "Throwable")
	if self.IsAiming() == aiming then
		return
	end
	self.IsAiming(aiming)

	const poseMachine = self.PoseMachine
	if poseMachine then
		poseMachine:SetAiming(aiming, gunData ~= nil and gunData.Scope ~= nil)
	end

	if aiming and not self:UsesDrawMarker() then
		self.DrawSoundToken += 1
		self:PlayDrawSound()
	end
end

function ArmsController:HasArrow(): boolean
	const ammo = self.Dependencies.WeaponController:ActiveAmmo()
	if os.clock() - self.LastShotAt < SHOT_AMMO_GRACE then
		return math.min(ammo, self.LastShotAmmo - 1) > 0
	end
	return ammo > 0
end

function ArmsController:OnDrawMarker()
	if self.DiscardStarted or not self:HasArrow() then
		return
	end
	self:PlayDrawSound()
end

function ArmsController:UsesDrawMarker(): boolean
	const gunData = self.Dependencies.WeaponController:GunData()
	const timing = if gunData then WeaponSounds.DrawTiming(gunData.DisplayName) else nil
	return timing ~= nil and timing.Marker ~= nil
end

function ArmsController:ScheduleEquipDrawSound()
	const gunData = self.Dependencies.WeaponController:GunData()
	const timing = if gunData then WeaponSounds.DrawTiming(gunData.DisplayName) else nil
	if not timing or timing.Marker then
		return
	end

	self.DrawSoundToken += 1
	const token = self.DrawSoundToken
	const gunID = self.EquippedWeaponID
	const delay = timing.Equip or 0
	if delay <= 0 then
		self:PlayDrawSound()
		return
	end

	task.delay(delay, function()
		if self.DrawSoundToken ~= token or self.EquippedWeaponID ~= gunID or self.DiscardStarted then
			return
		end
		self:PlayDrawSound()
	end)
end

function ArmsController:PlayDrawSound()
	const gunData = self.Dependencies.WeaponController:GunData()
	if not gunData then
		return
	end

	const soundName = WeaponSounds.DrawName(gunData.DisplayName)
	if soundName == "" then
		return
	end

	const now = os.clock()
	if now - self.LastDrawSound < DRAW_SOUND_DEBOUNCE then
		return
	end
	self.LastDrawSound = now

	const camera = workspace.CurrentCamera
	if camera then
		WeaponSounds.PlayPooled(soundName, camera)
	else
		WeaponSounds.Play2D(soundName)
	end
end

function ArmsController:ScheduleDrawSound(gunData: GetGun.GunData)
	const declaredDraw = WeaponSounds.DrawTiming(gunData.DisplayName)
	const drawTiming = if declaredDraw and declaredDraw.Marker == nil then declaredDraw else nil
	const pumpTiming = WeaponSounds.PumpTiming(gunData.DisplayName)
	if not drawTiming and not pumpTiming then
		return
	end

	self.DrawSoundToken += 1
	const token = self.DrawSoundToken
	const gunID = self.EquippedWeaponID
	const ammoAtShot = self.Dependencies.WeaponController:ActiveAmmo()

	local function fire(play: () -> ())
		if self.DrawSoundToken ~= token or self.EquippedWeaponID ~= gunID or self.DiscardStarted then
			return
		end
		const remaining = math.min(self.Dependencies.WeaponController:ActiveAmmo(), ammoAtShot - 1)
		if remaining <= 0 then
			return
		end
		play()
	end

	for _, entry in {
		{ timing = pumpTiming, play = function() self:PlayPumpSound() end },
		{ timing = drawTiming, play = function() self:PlayDrawSound() end },
	} do
		const timing = entry.timing
		if timing then
			if timing.AfterShot <= 0 then
				fire(entry.play)
			else
				task.delay(timing.AfterShot, fire, entry.play)
			end
		end
	end
end

function ArmsController:PlayPumpSound()
	const gunData = self.Dependencies.WeaponController:GunData()
	if not gunData then
		return
	end

	const soundName = WeaponSounds.PumpName(gunData.DisplayName)
	if soundName == "" then
		return
	end

	const camera = workspace.CurrentCamera
	if camera then
		WeaponSounds.PlayPooled(soundName, camera)
	else
		WeaponSounds.Play2D(soundName)
	end
end

function ArmsController:PlayShoot()
	self.LastShotAt = os.clock()
	self.LastShotAmmo = self.Dependencies.WeaponController:ActiveAmmo()
	const poseMachine = self.PoseMachine
	if poseMachine then
		poseMachine:PlayShoot()
	end

	const gunData = self.Dependencies.WeaponController:GunData()
	if gunData then
		self:ScheduleDrawSound(gunData)
	end
end

function ArmsController:PlayReload()
	const poseMachine = self.PoseMachine
	if poseMachine then
		poseMachine:PlayReload()
	end
end

function ArmsController:PlayAttack()
	const poseMachine = self.PoseMachine
	if poseMachine then
		poseMachine:PlayAttack()
	end
end

function ArmsController:BeginThrow()
	const poseMachine = self.PoseMachine
	if poseMachine then
		poseMachine:BeginThrow()
	end
end

function ArmsController:SetThrowStance(long: boolean)
	const poseMachine = self.PoseMachine
	if poseMachine then
		poseMachine:SetThrowStance(long)
	end
end

function ArmsController:ReleaseThrow(short: boolean)
	const poseMachine = self.PoseMachine
	if poseMachine then
		poseMachine:ReleaseThrow(short)
	end
end

function ArmsController:ThrowReleaseDelay(short: boolean): number
	const poseMachine = self.PoseMachine
	return if poseMachine then poseMachine:ThrowReleaseDelay(short) else 0
end

function ArmsController:SetWeaponHidden(hidden: boolean)
	const weaponModel = self.WeaponModel
	if not weaponModel then
		return
	end

	for _, descendant in weaponModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = if hidden then 1 else 0
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

function ArmsController:IsEmpty(): boolean
	const weapon = self.Dependencies.WeaponController
	const gunData = weapon:GunData()
	return gunData ~= nil and GetGun.UsesAmmo(gunData) and weapon:ActiveAmmo() <= 0
end

function ArmsController:IsEmptyThrowable(): boolean
	const gunData = self.Dependencies.WeaponController:GunData()
	return gunData ~= nil and gunData.PoseKind == "Throwable" and self:IsEmpty()
end

function ArmsController:StepDiscard()
	if self.DiscardStarted or not self:IsEmpty() then
		return
	end
	self.DiscardStarted = true

	const gunData = self.Dependencies.WeaponController:GunData()
	if gunData and gunData.PoseKind == "Throwable" then
		return
	end

	const poseMachine = self.PoseMachine
	if poseMachine then
		poseMachine:PlayDiscard()
	end
end

local function discardFolder(): Folder
	const existing = workspace:FindFirstChild(DISCARD_FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end

	const folder = Instance.new("Folder")
	folder.Name = DISCARD_FOLDER
	folder.Parent = workspace
	return folder
end

function ArmsController:TossWeapon(gunID: number)
	const model = self.WeaponModel
	const camera = workspace.CurrentCamera
	const gunData = GetGun.ByID(gunID)
	if not model or not camera or not gunData or self.EquippedWeaponID ~= gunID then
		return
	end
	if gunData.PoseKind == "Throwable" then
		return
	end

	const clone = model:Clone()
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Motor6D") and (descendant.Name == "ArmWeld" or descendant.Name == "BodyWeld") then
			descendant:Destroy()
		end
	end

	const parts: { BasePart } = {}
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = false
			descendant.LocalTransparencyModifier = 0
			table.insert(parts, descendant)
		end
	end

	clone.Parent = discardFolder()
	self:SetWeaponHidden(true)

	const root = clone.PrimaryPart
	if root then
		root.AssemblyLinearVelocity = camera.CFrame:VectorToWorldSpace(DISCARD_VELOCITY)
		root.AssemblyAngularVelocity = Vector3.new(
			(math.random() - 0.5) * 2 * DISCARD_SPIN,
			(math.random() - 0.5) * 2 * DISCARD_SPIN,
			(math.random() - 0.5) * 2 * DISCARD_SPIN
		)
	end

	task.delay(DISCARD_COLLIDE_DELAY, function()
		for _, part in parts do
			if part.Parent then
				part.CanCollide = true
			end
		end
	end)
	Debris:AddItem(clone, DISCARD_LIFETIME)
end

function ArmsController:GetWeaponRootPosition(): Vector3?
	const weaponModel = self.WeaponModel
	const root = if weaponModel then weaponModel.PrimaryPart else nil
	return if root then root.Position else nil
end

function ArmsController:GetPoseState(): PoseMachine.PoseState?
	const poseMachine = self.PoseMachine
	return if poseMachine then poseMachine:GetState() else nil
end

function ArmsController:IsShootAimPlaying(): boolean
	const poseMachine = self.PoseMachine
	return if poseMachine then poseMachine:IsShootAimPlaying() else false
end

function ArmsController:GetMuzzlePosition(): Vector3?
	const weaponModel = self.WeaponModel
	const camera = workspace.CurrentCamera
	if weaponModel and camera then
		const muzzle = WeaponVFX.MuzzleCFrame(weaponModel, camera.CFrame.LookVector)
		if muzzle then
			return muzzle.Position
		end
	end

	const rig = self.Rig
	const rightArm = if rig then (rig:FindFirstChild("Right Arm") :: BasePart?) else nil
	return if rightArm then rightArm.Position else nil
end

function ArmsController:OnPumpMarker()
	if self.Dependencies.WeaponController:ActiveAmmo() > 0 then
		return
	end

	self.Libs.Net.Weapon.DiscardWeapon:fireServer()
end

function ArmsController:StepCharacter()
	const character = if self.Dependencies.GameStateController:Can("Viewmodel")
		then self.Dependencies.MovementController.Character
		else nil
	if character == self.RiggedCharacter then
		return
	end

	self.RiggedCharacter = character
	if character then
		self:RebuildRig(character)
	else
		self:ClearRig()
	end
end

function ArmsController:StepLoadout()
	if not self.Rig then
		return
	end

	const weapon = self.Dependencies.WeaponController
	if weapon:WeaponID() == self.EquippedWeaponID and weapon.ActiveSlot() == self.EquippedSlot then
		return
	end

	self:EquipCurrentGun()
end

function ArmsController:FollowCamera(deltaTime: number)
	const camera = workspace.CurrentCamera
	const rig = self.Rig
	if not camera or not rig then
		return
	end

	const targetOffset = if self.IsAiming() then AIM_OFFSET else HIP_OFFSET
	const alpha = 1 - math.exp(-OFFSET_TRANSITION_RATE * deltaTime)
	self.CurrentOffset = self.CurrentOffset:Lerp(targetOffset, alpha)
	rig:PivotTo(camera.CFrame * self.CurrentOffset)
end

function ArmsController:BindKeys()
	const aimHandle =
		self.Dependencies.InputController:Bind({
			Name = "Aim",
			Key = Enum.UserInputType.MouseButton2,
			Priority = 10,
			Requires = "Viewmodel",
		})
	aimHandle.OnPress(function()
		self:SetAiming(true)
	end)
	aimHandle.OnRelease(function()
		self:SetAiming(false)
	end)

	self.Dependencies.InputController
		:Bind({ Name = "Reload", Key = Enum.KeyCode.R, Priority = 10, Requires = "Viewmodel" })
		.OnPress(function()
			self:PlayReload()
		end)
end

ArmsController:OnTick(function(self)
	self:StepCharacter()
	self:StepLoadout()
	self:StepDiscard()
end, TICK_RATE)

ArmsController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Weapon.Discarded:onClient(function(packet)
		self:TossWeapon(packet.Gun)
	end)
end)

ArmsController:OnStart(function(self)
	self:BindKeys()

	self.Dependencies.GameStateController:Watch("Viewmodel", function(on: boolean)
		if not on then
			self:SetAiming(false)
		end
	end)

	RunService:BindToRenderStep(RENDER_BIND_NAME, Enum.RenderPriority.Camera.Value + 2, function(deltaTime: number)
		self:FollowCamera(deltaTime)
	end)
end)

return ArmsController
