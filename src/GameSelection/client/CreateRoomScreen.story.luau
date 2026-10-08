--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local CreateRoomScreen = require(StarterPlayer.StarterPlayerScripts.client.GameSelection.CreateRoomScreen)

return function(target)
	return vide.mount(function()
		return CreateRoomScreen({
			Visible = function()
				return true
			end,
		})
	end, target)
end
