--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local JoinRoomScreen = require(StarterPlayer.StarterPlayerScripts.client.GameSelection.JoinRoomScreen)

return function(target)
	return vide.mount(function()
		return JoinRoomScreen({
			Visible = function()
				return true
			end,
		})
	end, target)
end
