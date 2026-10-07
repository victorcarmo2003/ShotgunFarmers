--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local FriendsScreen = require(StarterPlayer.StarterPlayerScripts.client.Party.FriendsScreen)

return function(target)
	return vide.mount(function()
		return FriendsScreen({
			Visible = function()
				return true
			end,
			Sent = function()
				return { [156] = true }
			end,
		})
	end, target)
end
