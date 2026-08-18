local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FSM = require(ReplicatedStorage.Shared.Utils.FSM)

local Modux = require(game.ReplicatedStorage.Shared.Modux)
local MovementComponent = Modux.Component("MovementComponent"):Tag("MovementComponent"):ClassName("Instance")
type Self = typeof(MovementComponent)

export type MovementStates = "Walking" | "Running" | "Crouch" | "Sliding" | "Jumping" | "Dead"
local transitions: FSM.Transitions<MovementStates> = {
	Walking = { "Running", "Crouch", "Sliding", "Jumping", "Dead" },
	Running = { "Walking", "Crouch", "Sliding", "Jumping", "Dead" },
	Crouch = { "Walking", "Running", "Jumping", "Dead" },
	Sliding = { "Walking", "Running", "Jumping", "Dead" },
	Jumping = { "Walking", "Running", "Dead" },
}

MovementComponent.StartWalk = function(self: Self, player)
	local result = self.State:Transition("Walking")
	if result then
		self.Network.Packages.ChangeWalkSpeed:send({ WalkSpeed = 28 }, self.Instance)
	end
	return result
end

MovementComponent.StartRun = function(self: Self, player)
	local result = self.State:Transition("Running")
	if result then
		self.Network.Packages.ChangeWalkSpeed:send({ WalkSpeed = 28 }, self.Instance)
	end
	return result
end

MovementComponent.StartCrouch = function(self: Self, player)
	if self.State:Is("Crouch") then
		if self.State:Transition("Walking") then
			self.Network.Packages.ChangeWalkSpeed:send({ WalkSpeed = 28 }, self.Instance)
			return true
		end
		return false
	end

	local result = self.State:Transition("Crouch")
	if result then
		self.Network.Packages.ChangeWalkSpeed:send({ WalkSpeed = 10 }, self.Instance)
	end
	return result
end

MovementComponent.StartSlide = function(self: Self, player)
	if self.State:Is("Sliding") then
		if self.State:Transition("Walking") then
			self.Network.Packages.ChangeWalkSpeed:send({ WalkSpeed = 28 }, self.Instance)
			return true
		end
		return false
	end

	local result = self.State:Transition("Sliding")
	if result then
		self.Network.Packages.ChangeWalkSpeed:send({ WalkSpeed = 0 }, self.Instance)
	end
	return result
end

MovementComponent:OnInit(function(self)
	self.State = FSM.new<<MovementStates>>("Walking", transitions)

	self:Cleanup(self.State:OnTransition(function(_previousState, nextState)
		self.Network.Packages.MovementState:send({ State = nextState }, self.Instance)
	end))

	self:Cleanup((self.Instance :: Player).CharacterAdded:Connect(function()
		self.State:ForceState("Walking")
		self.Network.Packages.ChangeWalkSpeed:send({ WalkSpeed = 28 }, self.Instance)
	end))

	self.Network.Packages.ChangeMovement:on(
		function(request: { ActionName: string }, player: Player?): { CanDo: boolean }?
			if player ~= self.Instance then
				return
			end
			if request.ActionName == "Sprint" then
				return { CanDo = self:StartRun() }
			end

			if request.ActionName == "Walk" then
				return { CanDo = self:StartWalk() }
			end

			if request.ActionName == "Crouch" then
				return { CanDo = self:StartCrouch(player) }
			end

			if request.ActionName == "Slide" then
				return { CanDo = self:StartSlide(player) }
			end

			if request.ActionName == "Jump" then
				return { CanDo = true }
			end
			return { CanDo = false }
		end
	)
end)

return MovementComponent
