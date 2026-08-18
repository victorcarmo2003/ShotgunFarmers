--!strict
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local ProfileController = Modux.Controller("ProfileController")

ProfileController:OnInit(function(self)
	local packages = self.Network.Packages
	packages.Data:on(function(data, sender: Player?, timestamp: number?) end)

	packages.DataKey:onKey(function(key, value, sender: Player?, timestamp: number?) end)
end)

return ProfileController
