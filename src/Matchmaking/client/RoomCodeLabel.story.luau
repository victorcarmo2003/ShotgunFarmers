--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local RoomCodeLabel = require(StarterPlayer.StarterPlayerScripts.client.Matchmaking.RoomCodeLabel)

return function(target)
	return vide.mount(function()
		return RoomCodeLabel({
			Code = function()
				return "K7QZ2"
			end,
		})
	end, target)
end
