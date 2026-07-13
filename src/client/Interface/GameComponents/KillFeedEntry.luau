local StarterPlayer = game:GetService("StarterPlayer")
local Component = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Components)
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)

local Children = Fusion.Children

local THUMB_SIZE = 24
local GUN_ICON_SIZE = 20

export type KillFeedEntryValues = {
	LayoutOrder: number,
	ShooterName: string,
	ShooterImage: string,
	VictimName: string,
	VictimImage: string,
	GunName: string,
	GunImage: string,
	IsHeadshot: boolean,
}

local function thumbnail(scope: Fusion.Scope, name: string, image: string, order: number)
	return Component.ImageLabel(scope, {
		Name = name,
		Size = UDim2.fromOffset(THUMB_SIZE, THUMB_SIZE),
		BackgroundTransparency = 1,
		Image = image,
		LayoutOrder = order,
		ScaleType = Enum.ScaleType.Fit,
		[Children] = {
			Component.UICorner(scope, { CornerRadius = UDim.new(1, 0) }),
		},
	})
end


local function nameLabel(scope: Fusion.Scope, name: string, text: string, order: number)
	return Component.TextLabel(scope, {
		Name = name,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 14,
		LayoutOrder = order,
	})
end
-- Uma linha do KillFeed, na ordem pedida: [foto do atirador] [nome] [ícone da arma]
-- [tag de headshot, se for] [foto de quem morreu] [nome]. `LayoutOrder` negativo (ver
-- KillFeedController.PushEntry) garante que a entrada mais nova sempre fica em cima.
return function(scope: Fusion.Scope, values: KillFeedEntryValues)
	return Component.Frame(scope, {
		Name = "Entry",
		LayoutOrder = values.LayoutOrder,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(1, 0.1),
		BackgroundTransparency = 1,
		Visible = true,

		[Children] = {
			UIListLayout = Component.UIListLayout(scope, {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 6),
			}),

			ShooterImage = thumbnail(scope, "ShooterImage", values.ShooterImage, 0),
			ShooterName = nameLabel(scope, "ShooterName", values.ShooterName, 1),

			GunImage = Component.ImageLabel(scope, {
				Name = "GunImage",
				Size = UDim2.fromOffset(GUN_ICON_SIZE, GUN_ICON_SIZE),
				BackgroundTransparency = 1,
				Image = values.GunImage,
				ScaleType = Enum.ScaleType.Fit,
				LayoutOrder = 2
			}),

			HeadshotTag = Component.TextLabel(scope, {
				Name = "HeadshotTag",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				BackgroundTransparency = 1,
				Text = "HS",
				TextColor3 = Color3.fromRGB(255, 210, 60),
				TextSize = 14,
				Visible = values.IsHeadshot,
				LayoutOrder = 3,
			}),

			VictimImage = thumbnail(scope, "VictimImage", values.VictimImage, 4),
			VictimName = nameLabel(scope, "VictimName", values.VictimName, 5),
		},
	})
end
