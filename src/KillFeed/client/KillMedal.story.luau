--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local KillMedal = require(script.Parent.KillMedal)
local MedalSettings = require(ReplicatedStorage.shared.KillFeed.MedalSettings)

const create = Vide.create

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Text = "DOUBLE KILL",
		Streak = 4,
		Elapsed = 0.5,
	},
}, function(props)
	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(24, 24, 28),

		KillMedal({
			Text = function()
				return props.controls.Text()
			end,
			SubText = function()
				const streak = props.controls.Streak()
				return if streak >= MedalSettings.StreakMin then string.format(MedalSettings.StreakFormat, streak) else ""
			end,
			Color = function()
				return MedalSettings.MultiColor
			end,
			Elapsed = function()
				return props.controls.Elapsed()
			end,
		}),
	})
end)
