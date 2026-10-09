--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local Announcement = require(StarterPlayer.StarterPlayerScripts.client.Shop.Announcement)

return function(target)
	return vide.mount(function()
		return Announcement({
			Message = function()
				return "dev_Hakor started a CROP DROP!"
			end,
			Alpha = function()
				return 1
			end,
		})
	end, target)
end
