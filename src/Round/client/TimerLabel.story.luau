--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local TimerLabel = require(script.Parent.TimerLabel)

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Text = "00:30",
	},
}, function(props)
	return TimerLabel({
		Text = function()
			return props.controls.Text()
		end,
		Position = UDim2.fromScale(0.5, 0.5),
	})
end)
