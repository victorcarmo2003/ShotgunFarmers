--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local RanksScreen = require(StarterPlayer.StarterPlayerScripts.client.Rank.RanksScreen)

return function(target)
	return vide.mount(function()
		return RanksScreen({
			Visible = function()
				return true
			end,
		})
	end, target)
end