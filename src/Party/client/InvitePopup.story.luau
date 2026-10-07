--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local InvitePopup = require(StarterPlayer.StarterPlayerScripts.client.Party.InvitePopup)

return function(target)
	return vide.mount(function()
		return InvitePopup({
			Visible = function()
				return true
			end,
			UserId = function()
				return 1
			end,
			Name = function()
				return "Builderman"
			end,
			Progress = function()
				return 0.6
			end,
		})
	end, target)
end
