local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local GetGun = require(ReplicatedStorage.Shared.Utils.GetGun)
local GetAnimations = require(ReplicatedStorage.Shared.Utils.GetAnimations)
local GameSettings = require(ReplicatedStorage.Shared.Settings.GameSettings)
local buildViewmodelRig = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.Arms.RigBuilder)
local AnimationSetLoader = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.Arms.AnimationSetLoader)
local PoseMachine = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.Arms.PoseMachine)

local ArmsController = Modux.Controller("ArmsController"):Import("WeaponController"):Import("InputController")
type Self = typeof(ArmsController)

local HIP_OFFSET = CFrame.new(0, -2, -0.796)

local AIM_OFFSET = HIP_OFFSET
local OFFSET_TRANSITION_RATE = 12

local RENDER_BIND_NAME = "ArmsController_Follow"
local CHARACTER_ANIMATOR_WAIT_TIMEOUT = 5

local WEAPON_ASSET_WAIT_TIMEOUT = 5

local function hideSurfaceGuis(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("SurfaceGui") then
			descendant.Enabled = false
		end
	end
end

ArmsController.EquipViewmodel = function(self: Self, gunData: GetGun.GunData?)
	if self.WeaponModel then
		self.WeaponModel:Destroy()
		self.WeaponModel = nil
	end
	AnimationSetLoader.Unload(self.ViewmodelTracks)
	self.ViewmodelTracks = nil

	if not gunData or not self.Rig then
		return
	end

	local assetsFolder = ReplicatedStorage:WaitForChild("Assets", WEAPON_ASSET_WAIT_TIMEOUT)
	local weaponsFolder = assetsFolder and assetsFolder:WaitForChild("Weapons", WEAPON_ASSET_WAIT_TIMEOUT)
	local weaponAsset = weaponsFolder and weaponsFolder:WaitForChild(gunData.DisplayName, WEAPON_ASSET_WAIT_TIMEOUT)
	if weaponAsset then
		local weaponModel = weaponAsset:Clone() :: Model
		for _, descendant in weaponModel:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanQuery = false
			end
		end

		weaponModel.Parent = self.Rig
		self.WeaponModel = weaponModel

		local rightArm = self.Rig:FindFirstChild("Right Arm") :: BasePart?
		local rightGrip = rightArm and (rightArm:FindFirstChild("RightGripAttachment") :: Attachment?)
		local weaponGrip = weaponModel:FindFirstChild("Grip", true) :: Attachment?
		local handle = weaponModel.PrimaryPart
		if not handle then
			handle = weaponModel:FindFirstChild("Handle", true)
		end

		if rightArm and rightGrip and weaponGrip and handle then
			weaponModel:PivotTo(rightGrip.WorldCFrame * weaponGrip.CFrame:Inverse())

			local handleMotor = handle:FindFirstChildOfClass("Motor6D")
			if handleMotor then
				handleMotor.Part0 = rightArm
				handleMotor.Part1 = handle
				handleMotor.C0 = rightGrip.CFrame
				handleMotor.C1 = weaponGrip.CFrame
			else
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = rightArm
				weld.Part1 = handle
				weld.Parent = weaponModel
			end

			for _, child in weaponModel:GetChildren() do
				if child:IsA("BasePart") and child ~= handle then
					local safetyWeld = Instance.new("WeldConstraint")
					safetyWeld.Part0 = handle
					safetyWeld.Part1 = child
					safetyWeld.Parent = child
				end
			end
		end
	end

	if self.Animator then
		local clips = GetAnimations:Viewmodel(gunData.AnimationSet)
		self.ViewmodelTracks = AnimationSetLoader.Load(self.Animator, clips :: any, "Viewmodel")
	end
end

ArmsController.EquipCharacterPose = function(self: Self, gunData: GetGun.GunData?)
	AnimationSetLoader.Unload(self.CharacterTracks)
	self.CharacterTracks = nil

	if self.PoseMachine then
		self.PoseMachine:Destroy()
		self.PoseMachine = nil
	end

	if not gunData or not self.CharacterAnimator then
		return
	end

	local clips = GetAnimations:CharacterPose(gunData.DisplayName)
	self.CharacterTracks = AnimationSetLoader.Load(self.CharacterAnimator, clips :: any, "Character")

	local poseMachine = PoseMachine.new(self.ViewmodelTracks or {}, self.CharacterTracks or {}, gunData.PoseKind)
	self.PoseMachine = poseMachine

	poseMachine:PlayDraw(gunData.DrawTime or GameSettings.WeaponDrawLock)
end

ArmsController.EquipCurrentGun = function(self: Self)
	local gunData = Fusion.peek(self.WeaponController.GunData)
	self:EquipViewmodel(gunData)
	self:EquipCharacterPose(gunData)
end

ArmsController.SetAiming = function(self: Self, aiming: boolean)
	if self.IsAiming == aiming then
		return
	end
	self.IsAiming = aiming

	self.IsAimingValue:set(aiming)

	if self.PoseMachine then
		self.PoseMachine:SetAiming(aiming)
	end
end

ArmsController.PlayShoot = function(self: Self)
	if self.PoseMachine then
		self.PoseMachine:PlayShoot()
	end
end

ArmsController.PlayReload = function(self: Self)
	if self.PoseMachine then
		self.PoseMachine:PlayReload()
	end
end

ArmsController.PlayAttack = function(self: Self)
	if self.PoseMachine then
		self.PoseMachine:PlayAttack()
	end
end

ArmsController.BeginThrow = function(self: Self)
	if self.PoseMachine then
		self.PoseMachine:BeginThrow()
	end
end

ArmsController.ReleaseThrow = function(self: Self)
	if self.PoseMachine then
		self.PoseMachine:ReleaseThrow()
	end
end

ArmsController.GetPoseState = function(self: Self): string?
	return self.PoseMachine and self.PoseMachine:GetState()
end

ArmsController.GetMuzzlePosition = function(self: Self): Vector3?
	if self.WeaponModel then
		local muzzle = self.WeaponModel:FindFirstChild("Muzzle", true) :: Attachment?
		if muzzle then
			return muzzle.WorldPosition
		end
	end

	local rightArm = self.Rig and (self.Rig:FindFirstChild("Right Arm") :: BasePart?)
	return rightArm and rightArm.Position
end

ArmsController.HideRig = function(self: Self)
	if self.Rig then
		self.Rig:Destroy()
		self.Rig = nil
	end
	self.WeaponModel = nil
end

ArmsController.RebuildRig = function(self: Self, character: Model)
	local rebuildStart = os.clock()
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
		local buildStart = os.clock()
		local rig, animator = buildViewmodelRig(character)
		print(`[ArmsController] buildViewmodelRig levou {os.clock() - buildStart}s`)

		if self.LocalPlayer.Character ~= character then
			if rig then
				rig:Destroy()
			end
			return
		end

		if self.Rig then
			self.Rig:Destroy()
			self.Rig = nil
		end

		if self.PoseMachine then
			self.PoseMachine:Destroy()
			self.PoseMachine = nil
		end
		self.WeaponModel = nil
		self.ViewmodelTracks = nil
		self.CharacterTracks = nil
		self.Animator = nil
		self.CharacterAnimator = nil

		if not rig then
			return
		end

		rig.Parent = workspace.CurrentCamera
		self.Rig = rig
		self.Animator = animator
		self.CurrentOffset = HIP_OFFSET
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local characterAnimator = humanoid and humanoid:WaitForChild("Animator", CHARACTER_ANIMATOR_WAIT_TIMEOUT)
		self.CharacterAnimator = characterAnimator :: Animator?

		self:EquipCurrentGun()
	end)
end

ArmsController:OnInit(function(self)
	self.LocalPlayer = Players.LocalPlayer :: Player
	self.Scope = Fusion.scoped(Fusion)
	self.IsAimingValue = self.Scope:Value(false) :: Fusion.Value<boolean>
	self.Rig = nil :: Model?
	self.WeaponModel = nil :: Model?
	self.Animator = nil :: Animator?
	self.ViewmodelTracks = nil :: AnimationSetLoader.TrackSet?
	self.CharacterAnimator = nil :: Animator?
	self.CharacterTracks = nil :: AnimationSetLoader.TrackSet?
	self.PoseMachine = nil :: PoseMachine.PoseMachine?
	self.CharacterGuiConnection = nil :: RBXScriptConnection?
	self.IsAiming = false :: boolean
	self.CurrentOffset = HIP_OFFSET :: CFrame

	self.Scope:Observer(self.WeaponController.GunData):onChange(function()
		self:EquipCurrentGun()
	end)

	self.Scope:Observer(self.WeaponController.ActiveSlot):onChange(function()
		self:EquipCurrentGun()
	end)
end)

ArmsController:OnStart(function(self)
	if self.LocalPlayer.Character then
		self:RebuildRig(self.LocalPlayer.Character)
	end

	self:Cleanup(self.LocalPlayer.CharacterAdded:Connect(function(character: Model)
		self:RebuildRig(character)
	end))

	local aimHandler = self.InputController:BindAction("Aim", Enum.UserInputType.MouseButton2)
	aimHandler.OnPress(function()
		self:SetAiming(true)
	end)
	aimHandler.OnRelease(function()
		self:SetAiming(false)
	end)

	local reloadHandler = self.InputController:BindAction("Reload", Enum.KeyCode.R)
	reloadHandler.OnPress(function()
		self:PlayReload()
	end)

	RunService:BindToRenderStep(RENDER_BIND_NAME, Enum.RenderPriority.Camera.Value + 2, function(deltaTime: number)
		local camera = workspace.CurrentCamera
		if not camera or not self.Rig then
			return
		end
		local targetOffset = if self.IsAiming then AIM_OFFSET else HIP_OFFSET
		local alpha = 1 - math.exp(-OFFSET_TRANSITION_RATE * deltaTime)
		self.CurrentOffset = self.CurrentOffset:Lerp(targetOffset, alpha)
		self.Rig:PivotTo(camera.CFrame * self.CurrentOffset)
	end)

	self:Cleanup(function()
		RunService:UnbindFromRenderStep(RENDER_BIND_NAME)
	end)
	self:Cleanup(function()
		if self.CharacterGuiConnection then
			self.CharacterGuiConnection:Disconnect()
		end
	end)
end)

return ArmsController
