--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local StatusBar = require(script.Parent.StatusBar)

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Health = 100,
		Armor = 100,
		PlayerName = "dev_Hakor",

		PlayerImage = "rbxthumb://type=AvatarBust&id=1&w=420&h=420",
	},
}, function(props)
	return StatusBar({
		Health = function()
			return props.controls.Health() / 100
		end,
		Armor = function()
			return props.controls.Armor() / 100
		end,
		PlayerName = function()
			return props.controls.PlayerName()
		end,
		PlayerImage = function()
			return props.controls.PlayerImage()
		end,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 190),
	})
end)
