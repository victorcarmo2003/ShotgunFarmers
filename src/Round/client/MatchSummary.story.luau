--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local MatchSummary = require(StarterPlayer.StarterPlayerScripts.client.Round.MatchSummary)

return function(target)
	return vide.mount(function()
		return MatchSummary({
			Visible = function()
				return true
			end,
			Summary = function()
				return {
					Outcome = "Victory",
					Placement = 1,
					Players = 8,
					Kills = 14,
					Deaths = 5,
					Assists = 3,
					Score = 15.5,
					XpGained = 185,
					GemsGained = 92,
					Level = 7,
					LevelsGained = 1,
					Xp = 40,
					XpMax = 177,
					Counted = true,
				}
			end,
		})
	end, target)
end
