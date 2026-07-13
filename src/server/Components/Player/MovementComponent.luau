local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FSM = require(ReplicatedStorage.Shared.Utils.FSM)

local Modux = require(game.ReplicatedStorage.Shared.Modux)
local MovementComponent = Modux.Component("MovementComponent"):Tag("MovementComponent"):ClassName("Instance")

export type MovementStates = "Walking" | "Running" | "Crouch" | "Sliding" | "Jumping" | "Dead"
local transitions: FSM.Transitions<MovementStates> = {
	Walking = { "Running", "Crouch", "Sliding", "Jumping", "Dead" }, -- can do everything
	Running = { "Walking", "Crouch", "Sliding", "Jumping", "Dead" }, -- can do everything
	Crouch = { "Walking", "Running", "Jumping", "Dead" }, -- can do everything
	Sliding = { "Walking", "Running", "Jumping", "Dead" }, -- can do everything (reservado, sem tecla vinculada por enquanto)
	Jumping = { "Walking", "Running", "Dead" },
}

MovementComponent.StartWalk = function(self, player)
	local result = self.State:Transition("Running")
	if result then
		self.Network.Packages.ChangeWalkSpeed:send({ WalkSpeed = 28 }, self.Instance)
	end
	return result
end

MovementComponent.StartRun = function(self, player)
	local result = self.State:Transition("Walking")
	if result then
		self.Network.Packages.ChangeWalkSpeed:send({ WalkSpeed = 28 }, self.Instance)
	end
	return result
end

MovementComponent.StartCrouch = function(self, player)
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

MovementComponent.StartSlide = function(self, player)
	if self.State:Is("Sliding") then
		if self.State:Transition("Walking") then
			self.Network.Packages.ChangeWalkSpeed:send({ WalkSpeed = 28 }, self.Instance)
			return true
		end
		return false
	end

	local result = self.State:Transition("Sliding")
	if result then
		-- WalkSpeed = 0 durante o slide: a velocidade horizontal é controlada
		-- diretamente pelo client (MovementController), não pelo Humanoid
		self.Network.Packages.ChangeWalkSpeed:send({ WalkSpeed = 0 }, self.Instance)
	end
	return result
end

MovementComponent:OnInit(function(self)
	-- Por instância (não mais na tabela do componente) -- antes era compartilhado por
	-- TODOS os jogadores, já que o Modux clona instâncias "Transient" com table.clone
	-- raso e só clona campos SEM metatable; o FSM tem metatable, então o campo antigo
	-- vazava o mesmo objeto de estado entre jogadores diferentes.
	self.State = FSM.new<<MovementStates>>("Walking", transitions)

	-- MovementComponent é tageado no Player (não no Character, ver MovementService),
	-- então OnInit só roda uma vez por sessão -- sem isso, o estado (Crouch/Sliding)
	-- de antes de morrer sobrevive ao respawn. Se você morresse deslizando (WalkSpeed
	-- enviado = 0), o único caminho de volta (tecla Crouch) falhava silenciosamente
	-- porque Sliding não pode transicionar direto pra Crouch -- ficava travado pra
	-- sempre. ForceState ignora a tabela de transições pra sempre conseguir resetar.
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
