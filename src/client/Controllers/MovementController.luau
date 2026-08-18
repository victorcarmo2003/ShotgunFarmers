local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Modux = require(ReplicatedStorage.Shared.Modux)
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local MovementController = Modux.Controller("MovementController")
	:Import("InputController")
	:Import("SurfaceUIController")
	:Import("CameraController")
type Self = typeof(MovementController)

export type MovementStates = "Walking" | "Running" | "Crouch" | "Sliding" | "Jumping" | "Dead"

local MOVING_THRESHOLD = 0.05

local MIN_FALL_SPEED = 1
local MAX_FALL_SPEED = 20
local MAX_FALL_SHAKE_INTENSITY = 1.2

local MIN_SLIDE_SPEED = 10
local MAX_SLIDE_SPEED = 50
local SLIDE_END_SPEED = 6
local SLIDE_TURN_RATE = 4
local SLIDE_FRICTION = 1.4

MovementController.GetCurrentPosition = function(self: Self)
	local primaryPart = self.LocalCharacter.PrimaryPart
	local origin = primaryPart.Position
	return origin
end

MovementController.GetMoveDirection = function(self: Self)
	local moveDirection = self.LocalHumanoid.MoveDirection
	return moveDirection
end

MovementController.OnLanded = function(self: Self, fallSpeed: number)
	if fallSpeed <= MIN_FALL_SPEED then
		return
	end

	local alpha = math.clamp((fallSpeed - MIN_FALL_SPEED) / (MAX_FALL_SPEED - MIN_FALL_SPEED), 0, 1)
	local mainUI = self.SurfaceUIController:Get("PlayerStatusUI")
	local gunUI = self.SurfaceUIController:Get("GunUI")
	if mainUI then
		self.SurfaceUIController:CreateEffect(mainUI, "Shake", alpha * MAX_FALL_SHAKE_INTENSITY)
	end
	if gunUI then
		self.SurfaceUIController:CreateEffect(gunUI, "Shake", alpha * MAX_FALL_SHAKE_INTENSITY)
	end
	self.CameraController:CreateEffect("Shake", alpha * MAX_FALL_SHAKE_INTENSITY)
end

MovementController.TryStartSlide = function(self: Self)
	local rootPart = self.LocalCharacter and self.LocalCharacter.PrimaryPart
	local humanoid = self.LocalHumanoid
	if not rootPart or not humanoid then
		return
	end

	if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		return
	end

	local flatVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z)
	if flatVelocity.Magnitude < MIN_SLIDE_SPEED then
		return
	end

	self.Network.Packages.ChangeMovement:send({ ActionName = "Slide" })

	self.SlideDirection = flatVelocity.Unit :: Vector3
	self.SlideSpeed = math.min(flatVelocity.Magnitude, MAX_SLIDE_SPEED) :: number
	self.IsSliding = true
	humanoid.AutoRotate = false
end

MovementController.StopSlide = function(self: Self)
	if not self.IsSliding then
		return
	end

	self.IsSliding = false
	if self.LocalHumanoid then
		self.LocalHumanoid.AutoRotate = true
	end
	self.Network.Packages.ChangeMovement:send({ ActionName = "Slide" })
end

MovementController.StepSlide = function(self: Self, deltaTime: number)
	if not self.IsSliding then
		return
	end

	local rootPart = self.LocalCharacter and self.LocalCharacter.PrimaryPart
	local humanoid = self.LocalHumanoid
	if not rootPart or not humanoid then
		self.IsSliding = false
		return
	end

	if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		self:StopSlide()
		return
	end

	local camera = workspace.CurrentCamera
	if camera then
		local flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
		if flatLook.Magnitude > 0 then
			local turnAlpha = 1 - math.exp(-SLIDE_TURN_RATE * deltaTime)
			self.SlideDirection = self.SlideDirection:Lerp(flatLook.Unit, turnAlpha).Unit
		end
	end

	self.SlideSpeed *= math.exp(-SLIDE_FRICTION * deltaTime)
	if self.SlideSpeed <= SLIDE_END_SPEED then
		self:StopSlide()
		return
	end

	local currentVelocity = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = Vector3.new(self.SlideDirection.X, 0, self.SlideDirection.Z) * self.SlideSpeed
		+ Vector3.new(0, currentVelocity.Y, 0)
	rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + self.SlideDirection)
end

MovementController.TrackSliding = function(self: Self)
	self:Cleanup(RunService.Heartbeat:Connect(function(deltaTime: number)
		self:StepSlide(deltaTime)
	end))
end

MovementController.TrackMoving = function(self: Self)
	self:Cleanup(RunService.Heartbeat:Connect(function()
		local humanoid = self.LocalHumanoid
		local isMoving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > MOVING_THRESHOLD
		if isMoving ~= Fusion.peek(self.IsMovingValue) then
			self.IsMovingValue:set(isMoving)
		end
	end))
end

MovementController.TrackFalling = function(self: Self)
	local fallSpeed = 0
	local previousState: Enum.HumanoidStateType? = nil

	self:Cleanup(RunService.Heartbeat:Connect(function()
		local humanoid = self.LocalHumanoid
		if not humanoid then
			previousState = nil
			return
		end

		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.Freefall then
			if previousState ~= Enum.HumanoidStateType.Freefall then
				fallSpeed = 0
			end

			local rootPart = self.LocalCharacter and self.LocalCharacter.PrimaryPart
			if rootPart then
				fallSpeed = math.min(fallSpeed, rootPart.AssemblyLinearVelocity.Y)
			end
		elseif state == Enum.HumanoidStateType.Landed and previousState == Enum.HumanoidStateType.Freefall then
			self:OnLanded(-fallSpeed)
		end

		previousState = state
	end))
end

MovementController.BindKeys = function(self: Self)
	local CHandler = self.InputController:BindAction("Crouch", Enum.KeyCode.C, true, 10)

	CHandler.OnPress(function()
		self.Network.Packages.ChangeMovement:send({ ActionName = "Crouch" })
	end)
end

MovementController:OnInit(function(self)
	self.Scope = Fusion.scoped(Fusion)
	self.IsMovingValue = self.Scope:Value(false) :: Fusion.Value<boolean>

	self.MovementState = self.Scope:Value("Walking" :: MovementStates) :: Fusion.Value<MovementStates>

	self.Network.Packages.ChangeWalkSpeed:on(function(data: { WalkSpeed: number })
		self.LocalHumanoid.WalkSpeed = data.WalkSpeed
	end)

	self.Network.Packages.MovementState:on(function(data: { State: MovementStates })
		self.MovementState:set(data.State)
	end)
end)

MovementController:OnStart(function(self)
	self:BindKeys()
	self:TrackFalling()
	self:TrackSliding()
	self:TrackMoving()
end)

return MovementController
