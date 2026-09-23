--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create

const TRACK_COLOR = Color3.fromRGB(32, 32, 32)
const DEFAULT_FILL = ColorSequence.new(Color3.fromRGB(0, 190, 159))

export type Props = {
	Percent: () -> number,
	Text: () -> string,
	Color: ColorSequence?,
	Icon: string?,
	Name: string?,
	LayoutOrder: number?,
	Size: UDim2?,
}

return function(props: Props): CanvasGroup
	return create("CanvasGroup")({
		Name = props.Name or "ProgressionBar",
		Size = props.Size or UDim2.fromScale(1, 0.5),
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,

		create("Frame")({
			Name = "Track",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = TRACK_COLOR,
			ClipsDescendants = true,

			create("Frame")({
				Name = "Fill",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				ZIndex = 2,
				BorderSizePixel = 0,
				Size = function()
					return UDim2.fromScale(math.clamp(props.Percent(), 0, 1), 1)
				end,

				create("UIGradient")({
					Color = props.Color or DEFAULT_FILL,
					Rotation = 90,
				}),
			}),

			create("Frame")({
				Name = "Content",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 3,

				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0.02, 0),
				}),

				CreateRaw("UIPadding")({
					PaddingLeft = UDim.new(0.02, 0),
				}),

				create("ImageLabel")({
					Name = "Icon",
					LayoutOrder = 1,
					Image = props.Icon or "",
					Size = UDim2.fromScale(0.15, 0.7),
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Fit,

					create("UIAspectRatioConstraint")({}),
				}),

				create("TextLabel")({
					Name = "Value",
					LayoutOrder = 2,
					Text = props.Text,
					TextSize = 34,
					TextColor3 = Color3.new(1, 1, 1),
					FontFace = Fonts.FredokaOne,
					BackgroundTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					Size = UDim2.fromScale(0.6, 1),
				}),
			}),
		}),
	})
end
