--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local TeamScore = require(StarterPlayer.StarterPlayerScripts.client.Stats.TeamScore)

return function(target)
	return vide.mount(function()
		return TeamScore({
			Visible = function()
				return true
			end,
			Red = function()
				return 42
			end,
			Blue = function()
				return 37.5
			end,
			LocalTeam = function()
				return "Blue"
			end,
		})
	end, target)
end
