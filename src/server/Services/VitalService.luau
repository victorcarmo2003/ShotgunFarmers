local CollectionService = game:GetService("CollectionService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local VitalService = Modux.Service("VitalService"):Import("PlayerService")

VitalService.OnPlayerDie = function(self, Player: Player)
	local character = Player.Character
	local HRP = character:FindFirstChild("HumanoidRootPart", true)

	warn(`breaking joints`)
	if character and HRP then
		self.Tools.BreakJoints(HRP)
	end

	warn(`destroying in 3 seconds`)
	task.delay(3, function()
		character:Destroy()
	end)

	warn(`died`)
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
