local CollectionService = game:GetService("CollectionService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local VitalService = Modux.Service("VitalService"):Import("PlayerService"):Import("SpawnService")

-- Segundos de ragdoll (BreakJoints) antes do respawn de verdade.
local RESPAWN_DELAY = 3

VitalService.OnPlayerDie = function(self, Player: Player)
	local character = Player.Character
	local HRP = character:FindFirstChild("HumanoidRootPart", true)

	if character and HRP then
		self.Tools.BreakJoints(HRP)
	end

	task.delay(RESPAWN_DELAY, function()
		print(`[VitalService] Respawnando {Player.Name} depois do delay de ragdoll`)
		self.SpawnService:RequestSpawn(Player)
	end)
end

VitalService:OnInit(function(self)
	self.Network.Packages.GetVitals:handle(function(_, Player: Player?)
		if not Player then
			return nil
		end

		local playerVital = self:GetComponent(Player, "VitalComponent")
		if not playerVital then
			return nil
		end

		return {
			Armor = playerVital.Armor,
			Health = playerVital.Health,
			Stamina = playerVital.Stamina,
		}
	end)

	self.PlayerService:OnPlayerAdded(function(Player: Player)
		CollectionService:AddTag(Player, "VitalComponent")
		task.delay(5, function() end)
	end)
end)

return VitalService
