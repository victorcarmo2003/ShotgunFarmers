--!strict
const ReplicatedStorage = game:GetService "ReplicatedStorage"
const Vide = require(ReplicatedStorage.Packages.Vide)
const Theme = require(ReplicatedStorage.shared.Interface.Theme)
const CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
const StarterPlayer = game:GetService "StarterPlayer"
const UISounds = require(StarterPlayer.StarterPlayerScripts.client.Interface.UISounds)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring

const CIRCLE_HEIGHT = 0.75
const HOVER_SCALE = 1.12
const PRESS_SCALE = 0.9
const SPRING_PERIOD = 0.15
const SPRING_DAMPING = 0.55
const PLUS_LENGTH = 0.42
const PLUS_THICKNESS = 0.09

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

	const hovered = source(false)
	const pressed = source(false)
	const scale = spring(function()
		return if pressed() then PRESS_SCALE elseif hovered() then HOVER_SCALE else 1
	end, SPRING_PERIOD, SPRING_DAMPING)

	return create "Frame" {
		Name = "InviteCircle",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.Visible,

		create "ImageButton" {
			Name = "Circle",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, CIRCLE_HEIGHT / 2),
			Size = UDim2.fromScale(1, CIRCLE_HEIGHT),
			BackgroundTransparency = 0.3,
			BackgroundColor3 = Color3.new(),
			Image = image,
			Activated = function()
				UISounds.Play("Click")
				props.Activated()
			end,

			MouseEnter = function()
				hovered(true)
				UISounds.Play("Hover")
			end,

			MouseLeave = function()
				hovered(false)
				pressed(false)
			end,

			MouseButton1Down = function()
				pressed(true)
			end,

			MouseButton1Up = function()
				pressed(false)
			end,

			CreateRaw "UIScale" {
				Scale = scale,
			},

			create "UIAspectRatioConstraint" {
				AspectRatio = 1,
			},

			create "Frame" {
				Name = "Plus",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(PLUS_LENGTH, PLUS_LENGTH),
				BackgroundTransparency = 1,
				Visible = function()
					return image() == ""
				end,

				create "Frame" {
					Name = "Horizontal",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, PLUS_THICKNESS / PLUS_LENGTH),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0,

					create "UICorner" {
						CornerRadius = UDim.new(1, 0),
					},
				},

				create "Frame" {
					Name = "Vertical",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(PLUS_THICKNESS / PLUS_LENGTH, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0,

					create "UICorner" {
						CornerRadius = UDim.new(1, 0),
					},
				},
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
