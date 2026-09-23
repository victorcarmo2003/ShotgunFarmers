--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CharacterNet = require(ReplicatedStorage.shared.Character.Net)
local FSMLib = require(ReplicatedStorage.shared.Libs.FSM)
local Modux = require(ServerScriptService.server.Modux)

type State = CharacterNet.MovementState

const WALK_SPEED = 28
const CROUCH_SPEED = 10
const SLIDE_SPEED = 0

const TRANSITIONS: FSMLib.Transitions<State> = {
	Walking = { "Running", "Crouch", "Sliding", "Jumping", "Dead" },
	Running = { "Walking", "Crouch", "Sliding", "Jumping", "Dead" },
	Crouch = { "Walking", "Running", "Jumping", "Dead" },
	Sliding = { "Walking", "Running", "Jumping", "Dead" },
	Jumping = { "Walking", "Running", "Dead" },
}

const Movement = Modux.Component("Movement", { Tag = "Movement" })

function Movement:Setup()
	self.Owner = self.Instance :: Player
	self.WalkSpeed = WALK_SPEED :: number
	self.State = self.Libs.FSM.new("Walking" :: State, TRANSITIONS) :: FSMLib.FSM<State>
end

function Movement:Publish()
	self.Libs.Net.Character.Movement:update(self.Owner.UserId, {
		State = self.State:GetState(),
		WalkSpeed = self.WalkSpeed,
	})
end

function Movement:Enter(state: State, walkSpeed: number): boolean
	if not self.State:Transition(state) then
		return false
	end

	self.WalkSpeed = walkSpeed
	self:Publish()
	return true
end

function Movement:StartWalk(): boolean
	return self:Enter("Walking", WALK_SPEED)
end

function Movement:StartRun(): boolean
	return self:Enter("Running", WALK_SPEED)
end

function Movement:StartCrouch(): boolean
	if self.State:Is("Crouch") then
		return self:StartWalk()
	end

	return self:Enter("Crouch", CROUCH_SPEED)
end

function Movement:StartSlide(): boolean
	if self.State:Is("Sliding") then
		return self:StartWalk()
	end

	return self:Enter("Sliding", SLIDE_SPEED)
end

function Movement:Perform(action: CharacterNet.MovementAction): boolean
	if action == "Walk" then
		return self:StartWalk()
	elseif action == "Sprint" then
		return self:StartRun()
	elseif action == "Crouch" then
		return self:StartCrouch()
	elseif action == "Slide" then
		return self:StartSlide()
	elseif action == "Jump" then
		return true
	end

	return false
end

function Movement:Reset()
	self.State:ForceState("Walking")
	self.WalkSpeed = WALK_SPEED
	self:Publish()
end

Movement:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Character.Movement:add(self.Owner.UserId, {
		State = self.State:GetState(),
		WalkSpeed = self.WalkSpeed,
	})

	self.Owner.CharacterAdded:Connect(function()
		self:Reset()
	end)
end)

Movement:OnDestroy(function(self)
	if self.Libs.Net.Character.Movement:get(self.Owner.UserId) then
		self.Libs.Net.Character.Movement:remove(self.Owner.UserId)
	end
end)

return Movement
