--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create
const spring = Vide.spring

const INACTIVE_COLOR = Color3.new(0.12549, 0.12549, 0.12549)
const ACTIVE_COLOR = Color3.new(0.35, 0.32, 0.14)

const COLOR_SPRING_PERIOD = 0.3

export type Props = {
	SlotNumber: string,
	Ammo: () -> string,
	IsActive: () -> boolean,
	Image: (() -> string)?,
	OnSelect: (() -> ())?,
	Name: string?,
	LayoutOrder: number?,
	Visible: boolean?,
	Size: UDim2?,
}

return function(props: Props): Frame
	const backgroundColor = spring(function()
		return if props.IsActive() then ACTIVE_COLOR else INACTIVE_COLOR
	end, COLOR_SPRING_PERIOD, 1)

	return create("Frame")({
		Name = props.Name or "WeaponSlot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.fromScale(0.6, 0.2),
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = 0,

		Active = true,

		InputBegan = function(input: InputObject)
			const onSelect = props.OnSelect
			if not onSelect then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				onSelect()
			end
		end,

		create("TextLabel")({
			Name = "SlotNumber",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.25, 0.3),
			BackgroundTransparency = 1,
			Text = props.SlotNumber,
			TextSize = 20,
			TextColor3 = Color3.new(1, 1, 1),
			FontFace = Fonts.FredokaOne,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 2,
		}),

		create("ImageLabel")({
			Name = "WeaponImage",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8),
			BackgroundTransparency = 1,
			Image = props.Image or "",
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 1,
		}),

		create("TextLabel")({
			Name = "Ammo",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(0.9, 0.9),
			Size = UDim2.fromScale(0.6, 0.4),
			BackgroundTransparency = 1,
			Text = props.Ammo,
			TextSize = 22,
			TextColor3 = Color3.new(1, 1, 1),
			FontFace = Fonts.FredokaOne,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			ZIndex = 2,
		}),
	})
end
