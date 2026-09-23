--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ProgressionBar = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ProgressionBar)

const create = Vide.create

const SHIELD_COLOR = ColorSequence.new(Color3.fromRGB(0, 105, 226))
const HEALTH_COLOR = ColorSequence.new(Color3.fromRGB(0, 158, 105))
const SHIELD_ICON = "rbxassetid://84000941134084"
const HEALTH_ICON = "rbxassetid://98924504834257"
const PORTRAIT_COLOR = Color3.fromRGB(32, 32, 32)

export type Props = {
	Health: () -> number,
	Armor: () -> number,
	PlayerName: () -> string,
	PlayerImage: () -> string,
	Position: UDim2?,
	Size: UDim2?,
}

local function asPercent(value: () -> number): () -> string
	return function()
		return `{math.floor(value() * 100)}%`
	end
end

return function(props: Props): CanvasGroup
	return create("CanvasGroup")({
		Name = "StatusBar",

		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.15, 0.895),
		Size = props.Size or UDim2.fromScale(0.3, 0.2),
		BackgroundTransparency = 1,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.05, 0),

			Wraps = true,
		}),

		CreateRaw("UIPadding")({
			PaddingLeft = UDim.new(0.05, 0),
		}),

		create("TextLabel")({
			Name = "PlayerName",
			LayoutOrder = 0,
			Text = props.PlayerName,
			Size = UDim2.fromScale(1, 0.3),
			TextSize = 42,
			TextColor3 = Color3.new(1, 1, 1),
			FontFace = Fonts.FredokaOne,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		create("ImageLabel")({
			Name = "PlayerImage",
			LayoutOrder = 1,
			Image = props.PlayerImage,
			Size = UDim2.fromScale(0.2, 0.45),
			BackgroundColor3 = PORTRAIT_COLOR,
		}),

		create("Frame")({
			Name = "PlayerStatus",
			LayoutOrder = 2,
			Size = UDim2.fromScale(0.7, 0.4),
			BackgroundTransparency = 1,

			create("UIGridLayout")({
				CellSize = UDim2.fromScale(1, 0.5),
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),

			ProgressionBar({
				Name = "ShieldBar",
				LayoutOrder = 1,
				Percent = props.Armor,
				Text = asPercent(props.Armor),
				Color = SHIELD_COLOR,
				Icon = SHIELD_ICON,
			}),

			ProgressionBar({
				Name = "HealthBar",
				LayoutOrder = 2,
				Percent = props.Health,
				Text = asPercent(props.Health),
				Color = HEALTH_COLOR,
				Icon = HEALTH_ICON,
			}),
		}),
	})
end
