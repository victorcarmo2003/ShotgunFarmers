--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const OnlineController = Modux.Controller("OnlineController", { Priority = 460 })

function OnlineController:Setup()
	self.Online = Vide.source(0) :: Vide.Source<number>
end

OnlineController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Lobby.Online:onClient(function(count)
		self.Online(count)
	end)
end)

return OnlineController
