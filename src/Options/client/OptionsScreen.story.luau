--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local OptionsScreen = require(StarterPlayer.StarterPlayerScripts.client.Options.OptionsScreen)

return function(target)
	return vide.mount(function()
		return OptionsScreen({
			Visible = function()
				return true
			end,
		})
	end, target)
end
