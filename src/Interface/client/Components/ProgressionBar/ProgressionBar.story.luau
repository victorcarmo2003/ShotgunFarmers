local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ProgressionBar = require(script.Parent)

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Percent = 0.65,
		Icon = "rbxassetid://98924504834257",
	},
}, function(props)
	return ProgressionBar({
		Percent = function()
			return props.controls.Percent()
		end,
		Text = function()
			return `{math.floor(props.controls.Percent() * 100)}%`
		end,
		Icon = props.controls.Icon(),
		Color = ColorSequence.new(Color3.fromRGB(0, 158, 105)),
		Size = UDim2.fromOffset(320, 64),
	})
end)
