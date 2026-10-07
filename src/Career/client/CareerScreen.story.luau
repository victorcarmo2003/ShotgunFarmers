--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local CareerScreen = require(StarterPlayer.StarterPlayerScripts.client.Career.CareerScreen)

return function(target)
	return vide.mount(function()
		return CareerScreen({
			Visible = function()
				return true
			end,
		})
	end, target)
end
