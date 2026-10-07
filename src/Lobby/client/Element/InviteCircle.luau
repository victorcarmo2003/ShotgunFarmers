--!strict
const ReplicatedStorage = game:GetService "ReplicatedStorage"
const Vide = require(ReplicatedStorage.Packages.Vide)
const Theme = require(ReplicatedStorage.shared.Interface.Theme)

const create = Vide.create

const CIRCLE_HEIGHT = 0.75

export type Props = {
	Visible: (() -> boolean)?,
	Image: (() -> string)?,
	Caption: (() -> string)?,
	Activated: () -> (),
}

return function(props: Props): Frame
	const image = function(): string
		return if props.Image then props.Image() else ""
	end

	const caption = function(): string
		return if props.Caption then props.Caption() else ""
	end

	return create "Frame" {
		Name = "InviteCircle",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.Visible,

		create "ImageButton" {
			Name = "Circle",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(1, CIRCLE_HEIGHT),
			BackgroundTransparency = 0.3,
			BackgroundColor3 = Color3.new(),
			Image = image,
			Activated = function()
				props.Activated()
			end,

			create "UIAspectRatioConstraint" {
				AspectRatio = 1,
			},

			create "TextLabel" {
				Name = "Plus",
				RichText = true,
				Text = "<b>+</b>",
				FontFace = Theme.Typography.Title,
				TextColor3 = Color3.new(1, 1, 1),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				TextScaled = true,
				Visible = function()
					return image() == ""
				end,
			},

			create "UICorner" {
				CornerRadius = UDim.new(1, 0),
			},
		},

		create "TextLabel" {
			Name = "Caption",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(1, 1 - CIRCLE_HEIGHT - 0.03),
			BackgroundColor3 = Color3.fromHex "#1F9F68",
			BackgroundTransparency = 0,
			RichText = true,
			Text = function()
				return `<b>{caption()}</b>`
			end,
			FontFace = Theme.Typography.Title,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Visible = function()
				return caption() ~= ""
			end,
		},
	}
end
