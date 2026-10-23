--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
local Vide = require(ReplicatedStorage.Packages.Vide)
local DamageNumber = require(script.Parent.DamageNumber)

const create = Vide.create
const source = Vide.source

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Headshot = false,
		Killed = false,
		Fading = false,
	},
}, function(props)
	const amount = source(24)
	const pop = source(0)

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(80, 120, 70),

		create("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromOffset(120, 48),
			BackgroundTransparency = 1,

			DamageNumber({
				Amount = amount,
				Headshot = props.controls.Headshot,
				Killed = props.controls.Killed,
				Pop = pop,
				Fading = props.controls.Fading,
			}),
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
				amount(amount() + 12)
				pop(pop() + 1)
			end,

			create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
		}),
	})
end)
