--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local GameSettings = require(ReplicatedStorage.shared.Settings.GameSettings)
local GetAnimations = require(ReplicatedStorage.shared.Character.GetAnimations)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local Vide = require(ReplicatedStorage.Packages.Vide)
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

local function hideSurfaceGuis(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("SurfaceGui") then
			descendant.Enabled = false
		end
	end
end

local function weaponAsset(displayName: string): Model?
	const asset = ReplicatedStorage.Assets.Weapons:FindFirstChild(displayName)
	return (if asset and asset:IsA("Model") then asset else nil) :: Model?
end

local function weldWeapon(rig: Model, weaponModel: Model, gunData: GetGun.GunData)
	const targetPart = rig:FindFirstChild(WELD_PART_NAMES[(gunData.WeldTo or "RightArm") :: GetGun.WeldPart]) :: BasePart?
	const handle = weaponModel.PrimaryPart or (weaponModel:FindFirstChild("Handle", true) :: BasePart?)
	if not targetPart or not handle then
		return
	end

	const armWeld = handle:FindFirstChild("ArmWeld") :: Motor6D?
	if armWeld then
		armWeld.Part0 = targetPart
		armWeld.Part1 = handle
	else
		const weld = Instance.new("WeldConstraint")
		weld.Part0 = targetPart
		weld.Part1 = handle
		weld.Parent = weaponModel
	end

	for _, child in weaponModel:GetChildren() do
		if child:IsA("BasePart") and child ~= handle then
			const safetyWeld = Instance.new("WeldConstraint")
			safetyWeld.Part0 = handle
			safetyWeld.Part1 = child
			safetyWeld.Parent = child
		end
	end
end

const ArmsController = Modux.Controller("ArmsController", {
	Require = { "WeaponController", "MovementController", "InputController" },
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
	self.CurrentOffset = HIP_OFFSET :: CFrame
end

function ArmsController:ClearViewmodel()
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
	poseMachine:PlayDraw(self:DrawSeconds(gunData))
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

	const gunData = weapon:GunData()
	self:EquipViewmodel(gunData)
	self:EquipCharacterPose(gunData)
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

function ArmsController:SetAiming(aiming: boolean)
	if self.IsAiming() == aiming then
		return
	end
	self.IsAiming(aiming)

	const poseMachine = self.PoseMachine
	if poseMachine then
		poseMachine:SetAiming(aiming)
	end
end

function ArmsController:PlayShoot()
	const poseMachine = self.PoseMachine
	if poseMachine then
		poseMachine:PlayShoot()
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

function ArmsController:ReleaseThrow()
	const poseMachine = self.PoseMachine
	if poseMachine then
		poseMachine:ReleaseThrow()
	end
end

function ArmsController:GetPoseState(): PoseMachine.PoseState?
	const poseMachine = self.PoseMachine
	return if poseMachine then poseMachine:GetState() else nil
end

function ArmsController:GetMuzzlePosition(): Vector3?
	const weaponModel = self.WeaponModel
	if weaponModel then
		const muzzle = weaponModel:FindFirstChild("Muzzle", true)
		if muzzle and muzzle:IsA("Attachment") then
			return muzzle.WorldPosition
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
	const character = self.Dependencies.MovementController.Character
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
		self.Dependencies.InputController:Bind({ Name = "Aim", Key = Enum.UserInputType.MouseButton2, Priority = 10 })
	aimHandle.OnPress(function()
		self:SetAiming(true)
	end)
	aimHandle.OnRelease(function()
		self:SetAiming(false)
	end)

	self.Dependencies.InputController
		:Bind({ Name = "Reload", Key = Enum.KeyCode.R, Priority = 10 })
		.OnPress(function()
			self:PlayReload()
		end)
end

ArmsController:OnTick(function(self)
	self:StepCharacter()
	self:StepLoadout()
end, TICK_RATE)

ArmsController:OnInit(function(self)
	self:Setup()
end)

ArmsController:OnStart(function(self)
	self:BindKeys()

	RunService:BindToRenderStep(RENDER_BIND_NAME, Enum.RenderPriority.Camera.Value + 2, function(deltaTime: number)
		self:FollowCamera(deltaTime)
	end)
end)

return ArmsController
