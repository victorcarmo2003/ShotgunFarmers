--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local DamageIndicator = require(StarterPlayer.StarterPlayerScripts.client.Vital.DamageIndicator)

return function(target)
	return vide.mount(function()
		return DamageIndicator({
			Hits = function()
				return { { Angle = 30, Alpha = 1 }, { Angle = 200, Alpha = 0.5 } }
			end,
			Flash = function()
				return 0.6
			end,
			LowHealth = function()
				return 0.7
			end,
		})
	end, target)
end
