--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local QuestsScreen = require(StarterPlayer.StarterPlayerScripts.client.Quests.QuestsScreen)

return function(target)
	return vide.mount(function()
		return QuestsScreen({
			Visible = function()
				return true
			end,
		})
	end, target)
end
