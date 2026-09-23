--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create

export type Props = {
	Text: () -> string,
	Position: UDim2?,
	Size: UDim2?,
}

return function(props: Props): TextLabel
	return create("TextLabel")({
		Name = "TimerLabel",

		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.1),
		Size = props.Size or UDim2.fromScale(0.2, 0.1),
		Text = props.Text,
		TextSize = 36,
		TextColor3 = Color3.new(1, 1, 1),
		FontFace = Fonts.FredokaOne,
		BackgroundTransparency = 1,
	})
end
