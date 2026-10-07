--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local GameSelectionScreen = require(StarterPlayer.StarterPlayerScripts.client.GameSelection.GameSelectionScreen)

return function(target)
	return vide.mount(function()
		return GameSelectionScreen({
			Visible = function()
				return true
			end,
		})
	end, target)
end
