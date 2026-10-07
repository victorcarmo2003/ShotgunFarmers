--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local LeaderstatsScreen = require(StarterPlayer.StarterPlayerScripts.client.Leaderstats.LeaderstatsScreen)

return function(target)
	return vide.mount(function()
		return LeaderstatsScreen({
			Mode = function()
				return "TDM"
			end,
			Visible = function()
				return true
			end,
		})
	end, target)
end
