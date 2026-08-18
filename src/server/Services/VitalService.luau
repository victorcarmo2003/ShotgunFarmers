local CollectionService = game:GetService("CollectionService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local VitalService = Modux.Service("VitalService"):Import("PlayerService"):Import("SpawnService")
type Self = typeof(VitalService)

VitalService.OnPlayerDie = function(self: Self, Player: Player)
	local character = Player.Character
	local HRP = character and character:FindFirstChild("HumanoidRootPart", true)

	if HRP then
		self.Tools.BreakJoints(HRP)
	end

	self.SpawnService:HandlePlayerDeath(Player)
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
