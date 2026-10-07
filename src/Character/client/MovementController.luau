--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local CharacterNet = require(ReplicatedStorage.shared.Character.Net)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

type MovementState = CharacterNet.MovementState
type MovementAction = CharacterNet.MovementAction
type MovementRecord = { State: MovementState, WalkSpeed: number }

const MOVING_THRESHOLD = 0.05

const MIN_FALL_SPEED = 1
const MAX_FALL_SPEED = 20
const MAX_FALL_SHAKE_INTENSITY = 1.2

const MIN_SLIDE_SPEED = 10
const MAX_SLIDE_SPEED = 50
const SLIDE_END_SPEED = 6
const SLIDE_TURN_RATE = 4
const SLIDE_FRICTION = 1.4

const CROUCH_CAMERA_OFFSET = Vector3.new(0, -1.5, 0)
const CROUCH_CAMERA_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

const MovementController = Modux.Controller("MovementController", {
	Require = { "InputController", "OptionsController" },
	Priority = 800,
})

function MovementController:Setup()
	self.Player = Players.LocalPlayer :: Player
	self.Character = nil :: Model?
	self.Humanoid = nil :: Humanoid?
	self.HumanoidConnection = nil :: RBXScriptConnection?

	self.MovementState = Vide.source("Walking") :: Vide.Source<MovementState>
	self.IsMoving = Vide.source(false) :: Vide.Source<boolean>

	self.WalkSpeed = nil :: number?
	self.CameraTween = nil :: Tween?

	self.IsSliding = false :: boolean
	self.SlideDirection = Vector3.zero :: Vector3
	self.SlideSpeed = 0 :: number

	self.FallSpeed = 0 :: number
	self.PreviousHumanoidState = nil :: Enum.HumanoidStateType?

	self.Landed = self.Libs.Signal.new() :: SignalLib.Signal<number>
end

function MovementController:CancelCameraTween()
	const tween = self.CameraTween
	if tween then
		tween:Cancel()
		tween:Destroy()
		self.CameraTween = nil
	end
end

function MovementController:ApplyCameraOffset(instant: boolean)
	const humanoid = self.Humanoid
	if not humanoid then
		return
	end

	self:CancelCameraTween()

	const target = if self.MovementState() == "Crouch" then CROUCH_CAMERA_OFFSET else Vector3.zero
	if instant then
		humanoid.CameraOffset = target
		return
	end

	if humanoid.CameraOffset == target then
		return
	end

	const tween = TweenService:Create(humanoid, CROUCH_CAMERA_TWEEN, { CameraOffset = target })
	self.CameraTween = tween
	tween:Play()
end

function MovementController:SetHumanoid(humanoid: Humanoid)
	self.Humanoid = humanoid
	self:ApplyWalkSpeed()
	self:ApplyCameraOffset(true)
end

function MovementController:BindCharacter(character: Model?)
	if self.HumanoidConnection then
		self.HumanoidConnection:Disconnect()
		self.HumanoidConnection = nil
	end

	self:EndSlide()
	self:CancelCameraTween()
	self.Character = character
	self.Humanoid = nil
	self.PreviousHumanoidState = nil

	if not character then
		return
	end

	const humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self:SetHumanoid(humanoid)
		return
	end

	self.HumanoidConnection = character.ChildAdded:Connect(function(child)
		if child:IsA("Humanoid") then
			self:SetHumanoid(child)
		end
	end)
end

function MovementController:GetCurrentPosition(): Vector3?
	const character = self.Character
	if not character then
		return nil
	end

	const primaryPart = character.PrimaryPart
	return if primaryPart then primaryPart.Position else nil
end

function MovementController:GetMoveDirection(): Vector3
	const humanoid = self.Humanoid
	return if humanoid then humanoid.MoveDirection else Vector3.zero
end

function MovementController:Perform(action: MovementAction): boolean
	const ok, reply = self.Libs.Net.Character.ChangeMovement:request({ Action = action })
	if not ok then
		warn(`[MovementController] {action} sem resposta do servidor: {tostring(reply)}`)
		return false
	end

	return reply.CanDo == true
end

function MovementController:ApplyWalkSpeed()
	const humanoid = self.Humanoid
	const walkSpeed = self.WalkSpeed
	if humanoid and walkSpeed then
		humanoid.WalkSpeed = walkSpeed
	end
end

function MovementController:Apply(record: MovementRecord)
	const previousState = self.MovementState()
	self.MovementState(record.State)
	self.WalkSpeed = record.WalkSpeed
	self:ApplyWalkSpeed()

	if (previousState == "Crouch") ~= (record.State == "Crouch") then
		self:ApplyCameraOffset(false)
	end

	if record.State ~= "Sliding" then
		self:EndSlide()
	end
end

function MovementController:TryStartSlide()
	const character = self.Character
	const humanoid = self.Humanoid
	if not character or not humanoid then
		return
	end

	if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		return
	end

	const rootPart = character.PrimaryPart
	if not rootPart then
		return
	end

	const flatVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z)
	if flatVelocity.Magnitude < MIN_SLIDE_SPEED then
		return
	end

	self.SlideDirection = flatVelocity.Unit
	self.SlideSpeed = math.min(flatVelocity.Magnitude, MAX_SLIDE_SPEED)
	self.IsSliding = true
	humanoid.AutoRotate = false

	task.spawn(function()
		if not self:Perform("Slide") then
			self:EndSlide()
		end
	end)
end

function MovementController:EndSlide()
	if not self.IsSliding then
		return
	end

	self.IsSliding = false
	const humanoid = self.Humanoid
	if humanoid then
		humanoid.AutoRotate = true
	end
end

function MovementController:StopSlide()
	if not self.IsSliding then
		return
	end

	self:EndSlide()
	task.spawn(function()
		self:Perform("Slide")
	end)
end

function MovementController:StepSlide(deltaTime: number)
	if not self.IsSliding then
		return
	end

	const character = self.Character
	const humanoid = self.Humanoid
	const rootPart = if character then character.PrimaryPart else nil
	if not rootPart or not humanoid then
		self:EndSlide()
		return
	end

	if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		self:StopSlide()
		return
	end

	const camera = workspace.CurrentCamera
	if camera then
		const flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
		if flatLook.Magnitude > 0 then
			const turnAlpha = 1 - math.exp(-SLIDE_TURN_RATE * deltaTime)
			self.SlideDirection = self.SlideDirection:Lerp(flatLook.Unit, turnAlpha).Unit
		end
	end

	self.SlideSpeed *= math.exp(-SLIDE_FRICTION * deltaTime)
	if self.SlideSpeed <= SLIDE_END_SPEED then
		self:StopSlide()
		return
	end

	const currentVelocity = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = Vector3.new(self.SlideDirection.X, 0, self.SlideDirection.Z) * self.SlideSpeed
		+ Vector3.new(0, currentVelocity.Y, 0)
	rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + self.SlideDirection)
end

function MovementController:OnLanded(fallSpeed: number)
	if fallSpeed <= MIN_FALL_SPEED then
		return
	end

	const alpha = math.clamp((fallSpeed - MIN_FALL_SPEED) / (MAX_FALL_SPEED - MIN_FALL_SPEED), 0, 1)
	self.Landed:Fire(alpha * MAX_FALL_SHAKE_INTENSITY)
end

function MovementController:StepFalling()
	const humanoid = self.Humanoid
	if not humanoid then
		self.PreviousHumanoidState = nil
		return
	end

	const state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Freefall then
		if self.PreviousHumanoidState ~= Enum.HumanoidStateType.Freefall then
			self.FallSpeed = 0
		end

		const character = self.Character
		const rootPart = if character then character.PrimaryPart else nil
		if rootPart then
			self.FallSpeed = math.min(self.FallSpeed, rootPart.AssemblyLinearVelocity.Y)
		end
	elseif
		state == Enum.HumanoidStateType.Landed
		and self.PreviousHumanoidState == Enum.HumanoidStateType.Freefall
	then
		self:OnLanded(-self.FallSpeed)
	end

	self.PreviousHumanoidState = state
end

function MovementController:StepMoving()
	const humanoid = self.Humanoid
	const isMoving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > MOVING_THRESHOLD
	if isMoving ~= self.IsMoving() then
		self.IsMoving(isMoving)
	end
end

function MovementController:BindKeys()
	const crouch = self.Dependencies.InputController
		:Bind({ Name = "Crouch", Key = Enum.KeyCode.C, TouchButton = true, Priority = 10, Requires = "FirstPerson" })

	crouch.OnPress(function()
		if self.Dependencies.OptionsController:ToggleCrouch() or self.MovementState() ~= "Crouch" then
			self:Perform("Crouch")
		end
	end)

	crouch.OnRelease(function()
		if not self.Dependencies.OptionsController:ToggleCrouch() and self.MovementState() == "Crouch" then
			self:Perform("Crouch")
		end
	end)
end

MovementController:OnInit(function(self)
	self:Setup()

	const userId = self.Player.UserId

	self.Libs.Net.Character.Movement:onAdded(function(id, record)
		if id == userId then
			self:Apply(record)
		end
	end)

	self.Libs.Net.Character.Movement:onChanged(function(id, record)
		if id == userId then
			self:Apply(record)
		end
	end)
end)

MovementController:OnStart(function(self)
	self:BindKeys()

	const player = self.Player
	self:BindCharacter(player.Character)

	player.CharacterAdded:Connect(function(character)
		self:BindCharacter(character)
	end)

	player.CharacterRemoving:Connect(function()
		self:BindCharacter(nil)
	end)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		self:StepSlide(deltaTime)
		self:StepMoving()
		self:StepFalling()
	end)
end)

return MovementController
