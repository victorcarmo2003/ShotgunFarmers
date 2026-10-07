--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local ShopScreen = require(StarterPlayer.StarterPlayerScripts.client.Shop.ShopScreen)

return function(target)
	return vide.mount(function()
		return ShopScreen({
			Visible = function()
				return true
			end,
		})
	end, target)
end
