--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local DeathScreen = require(StarterPlayer.StarterPlayerScripts.client.Vital.DeathScreen)

return function(target)
	return vide.mount(function()
		return DeathScreen({
			Visible = function()
				return true
			end,
			Info = function()
				return { Killer = "dev_Hakor", Gun = "Sniperagus", Headshot = true }
			end,
			Remaining = function()
				return 2.4
			end,
		})
	end, target)
end
