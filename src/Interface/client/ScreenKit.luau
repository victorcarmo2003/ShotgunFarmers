--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(ReplicatedStorage.shared.Interface.Theme)
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring

const REF_WIDTH = 1122
const REF_HEIGHT = 631
const MAX_TEXT_RATIO = 1080 / REF_HEIGHT

const HOVER_SCALE = 1.05
const PRESS_SCALE = 0.95
const SPRING_PERIOD = 0.15
const SPRING_DAMPING = 1

const ESCAPE_IMAGE = "rbxassetid://139855203093399"

local function escape(value: string): string
	return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

const ScreenKit = {}

ScreenKit.REF_WIDTH = REF_WIDTH
ScreenKit.REF_HEIGHT = REF_HEIGHT

ScreenKit.Colors = {
	Green = Color3.fromHex("#1F9F68"),
	Orange = Color3.fromHex("#FF9D00"),
	Black = Color3.new(0, 0, 0),
	White = Color3.new(1, 1, 1),
}

ScreenKit.DARK_TRANSPARENCY = 0.3

ScreenKit.Font = Theme.Typography.Title

ScreenKit.Images = {
	Escape = ESCAPE_IMAGE,
	Coin = "rbxassetid://123768928279796",
	Robux = "rbxassetid://119941510682170",
}

export type Text = string | () -> string

export type PressableProps = {
	Name: string,
	Position: UDim2,
	Size: UDim2,
	Color: (Color3 | () -> Color3)?,
	OnActivated: (() -> ())?,
	Children: { Instance }?,
}

export type ScreenProps = {
	Name: string,
	Visible: (() -> boolean)?,
	Children: { any },
}

function ScreenKit.at(x: number, y: number): UDim2
	return UDim2.fromScale(x / REF_WIDTH, y / REF_HEIGHT)
end

function ScreenKit.inside(x: number, y: number, width: number, height: number): UDim2
	return UDim2.fromScale(x / width, y / height)
end

function ScreenKit.label(text: Text, fontSize: number, boxHeight: number): TextLabel
	return create("TextLabel")({
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, fontSize / boxHeight),
		BackgroundTransparency = 1,
		FontFace = Theme.Typography.Title,
		RichText = true,
		Text = if typeof(text) == "function"
			then function()
				return `<b>{escape(text())}</b>`
			end
			else `<b>{escape(text)}</b>`,
		TextColor3 = ScreenKit.Colors.White,
		TextScaled = true,

		CreateRaw("UITextSizeConstraint")({
			MaxTextSize = math.round(fontSize * MAX_TEXT_RATIO),
		}),
	})
end

function ScreenKit.pressable(props: PressableProps): Frame
	const hovered = source(false)
	const pressed = source(false)
	const scale = spring(function()
		return if pressed() then PRESS_SCALE elseif hovered() then HOVER_SCALE else 1
	end, SPRING_PERIOD, SPRING_DAMPING)

	return create("Frame")({
		Name = props.Name,
		Position = props.Position,
		Size = props.Size,
		BackgroundTransparency = 1,

		create("ImageButton")({
			Name = "Button",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = props.Color or ScreenKit.Colors.Green,
			AutoButtonColor = false,

			Activated = function()
				if props.OnActivated then
					props.OnActivated()
				end
			end,
			MouseEnter = function()
				hovered(true)
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

			CreateRaw("UIScale")({
				Scale = scale,
			}),

			props.Children or {},
		}),
	})
end

export type TextProps = {
	Name: string,
	Text: Text,
	Position: UDim2,
	Size: UDim2,
	FontSize: number,
	BoxHeight: number,
	Color: (Color3 | () -> Color3)?,
	XAlignment: Enum.TextXAlignment?,
}

function ScreenKit.text(props: TextProps): Frame
	const text = props.Text
	return create("Frame")({
		Name = props.Name,
		Position = props.Position,
		Size = props.Size,
		BackgroundTransparency = 1,

		create("TextLabel")({
			Name = "Label",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromScale(1, props.FontSize / props.BoxHeight),
			BackgroundTransparency = 1,
			FontFace = Theme.Typography.Title,
			RichText = true,
			Text = if typeof(text) == "function"
				then function()
					return `<b>{escape(text())}</b>`
				end
				else `<b>{escape(text)}</b>`,
			TextColor3 = props.Color or ScreenKit.Colors.White,
			TextScaled = true,
			TextXAlignment = props.XAlignment or Enum.TextXAlignment.Center,

			CreateRaw("UITextSizeConstraint")({
				MaxTextSize = math.round(props.FontSize * MAX_TEXT_RATIO),
			}),
		}),
	})
end

function ScreenKit.stroke(color: Color3, thickness: number): UIStroke
	return CreateRaw("UIStroke")({
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function ScreenKit.panel(): Frame
	return create("Frame")({
		Name = "Panel",
		Position = ScreenKit.at(98, 102),
		Size = ScreenKit.at(926, 427),
		BackgroundColor3 = ScreenKit.Colors.Black,
		BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,
	})
end

function ScreenKit.header(text: Text): Frame
	return create("Frame")({
		Name = "Header",
		Position = ScreenKit.at(466, 80),
		Size = ScreenKit.at(190, 43),
		BackgroundColor3 = ScreenKit.Colors.Green,

		ScreenKit.label(text, 36, 43),
	})
end

function ScreenKit.returnButton(y: number, onClose: (() -> ())?): ImageButton
	return create("ImageButton")({
		Name = "Return",
		Position = ScreenKit.at(115, y),
		Size = ScreenKit.at(154, 33),
		BackgroundTransparency = 1,

		Activated = function()
			if onClose then
				onClose()
			end
		end,

		create("ImageLabel")({
			Name = "Key",
			Size = UDim2.fromScale(50 / 154, 1),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Image = ESCAPE_IMAGE,
		}),

		create("Frame")({
			Name = "Hint",
			Position = UDim2.fromScale(56 / 154, 3 / 33),
			Size = UDim2.fromScale(98 / 154, 28 / 33),
			BackgroundTransparency = 1,

			ScreenKit.label("TO RETURN", 24, 28),
		}),
	})
end

function ScreenKit.screen(props: ScreenProps): Frame
	return create("Frame")({
		Name = props.Name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.Visible or false,

		create("Frame")({
			Name = "Canvas",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,

			create("UIAspectRatioConstraint")({
				AspectRatio = REF_WIDTH / REF_HEIGHT,
			}),

			props.Children,
		}),
	})
end

return ScreenKit
