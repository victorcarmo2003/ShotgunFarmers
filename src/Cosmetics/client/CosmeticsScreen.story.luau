--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local CosmeticsScreen = require(StarterPlayer.StarterPlayerScripts.client.Cosmetics.CosmeticsScreen)

return function(target)
	return vide.mount(function()
		return CosmeticsScreen({
			Visible = function()
				return true
			end,
		})
	end, target)
end
