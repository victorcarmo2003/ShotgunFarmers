--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const RESPAWN_DELAY = 3

const VitalService = Modux.Service("VitalService", { Require = { "PlayerService" }, Priority = 700 })

function VitalService:Kill(player: Player)
	const character = player.Character
	if character then
		const humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end

	task.delay(RESPAWN_DELAY, function()
		if player.Parent ~= nil then
			player:LoadCharacter()
		end
	end)
end

VitalService:OnInit(function(self)
	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
		self.Components.Vital:Create(player)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.Components.Vital:Destroy(player)
	end)

	self.Dependencies.PlayerService.CharacterAdded:Connect(function(player)
		const vital = self.Components.Vital:Get(player)
		if vital then
			vital:Revive()
		end
	end)
end)

return VitalService
