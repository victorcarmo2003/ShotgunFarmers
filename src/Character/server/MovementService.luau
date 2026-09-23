--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const MovementService = Modux.Service("MovementService", { Require = { "PlayerService", "NetService" }, Priority = 700 })

MovementService:OnInit(function(self)
	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
		self.Components.Movement:Create(player)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.Components.Movement:Destroy(player)
	end)

	self.Libs.Net.Character.ChangeMovement:onServer(function(request, player)
		const movement = self.Components.Movement:Get(player)
		if not movement then
			return { CanDo = false }
		end

		return { CanDo = movement:Perform(request.Action) }
	end)
end)

return MovementService
