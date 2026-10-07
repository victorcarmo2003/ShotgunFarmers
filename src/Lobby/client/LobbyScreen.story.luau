--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local LobbyScreen = require(StarterPlayer.StarterPlayerScripts.client.Lobby.LobbyScreen)

return function(target)
	return vide.mount(function()
		return LobbyScreen({
			Balance = function()
				return 123456
			end,
			PlayersOnline = function()
				return 11239
			end,
			Visible = function()
				return true
			end,
		})
	end, target)
end
