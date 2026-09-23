--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
local Vide = require(ReplicatedStorage.Packages.Vide)
local HitMarker = require(script.Parent.HitMarker)

const create = Vide.create
const source = Vide.source

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Hits = 0,
	},
}, function(props)
	const clicks = source(0)

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(24, 24, 28),

		HitMarker({
			Trigger = function(): number
				return clicks() + props.controls.Hits()
			end,
		}),

		create("TextButton")({
			Name = "Hit",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -16),
			Size = UDim2.fromOffset(140, 36),
			BackgroundColor3 = Color3.fromRGB(46, 46, 52),
			Text = "Acertar",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 20,
			FontFace = Fonts.FredokaOne,
			Activated = function()
				clicks(clicks() + 1)
			end,

			create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
		}),
	})
end)
