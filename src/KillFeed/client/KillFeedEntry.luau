--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create

const THUMB_SIZE = 26
const GUN_ICON_SIZE = 18
const TEXT_SIZE = 26
const HEADSHOT_COLOR = Color3.fromRGB(255, 210, 60)

export type Entry = {
	ShooterName: string,
	ShooterImage: string,
	VictimName: string,
	VictimImage: string,
	GunName: string,
	GunImage: string,
	IsHeadshot: boolean,
}

export type Props = {
	Entry: Entry,

	LayoutOrder: () -> number,
}

local function thumbnail(name: string, image: string, order: number): ImageLabel
	return create("ImageLabel")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromOffset(THUMB_SIZE, THUMB_SIZE),
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,

		create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
	})
end

local function nameLabel(name: string, text: string, order: number): TextLabel
	return create("TextLabel")({
		Name = name,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = TEXT_SIZE,
		FontFace = Fonts.FredokaOne,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

return function(props: Props): Frame
	const entry = props.Entry

	return create("Frame")({
		Name = "Entry",
		LayoutOrder = props.LayoutOrder,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(1, 0.1),
		BackgroundTransparency = 1,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.02, 0),
		}),

		thumbnail("ShooterImage", entry.ShooterImage, 0),
		nameLabel("ShooterName", entry.ShooterName, 1),

		create("ImageLabel")({
			Name = "GunImage",
			LayoutOrder = 2,

			Size = UDim2.fromOffset(GUN_ICON_SIZE, GUN_ICON_SIZE),
			BackgroundTransparency = 1,
			Image = entry.GunImage,
			ScaleType = Enum.ScaleType.Fit,
		}),

		create("TextLabel")({
			Name = "HeadshotTag",
			LayoutOrder = 3,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			Text = "HS",
			TextColor3 = HEADSHOT_COLOR,
			TextSize = TEXT_SIZE,
			FontFace = Fonts.FredokaOne,
			Visible = entry.IsHeadshot,
		}),

		thumbnail("VictimImage", entry.VictimImage, 4),
		nameLabel("VictimName", entry.VictimName, 5),
	})
end
