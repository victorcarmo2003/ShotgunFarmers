local StarterPlayer = game:GetService("StarterPlayer")
local Component = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Components)
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)

local Children = Fusion.Children

export type progressionBarProps = {
	Color: ColorSequence | Color3?,
	Name: string?,
	LayoutOrder: number,
} & { any }

export type ProgressionBarValues = {
	Percent: Fusion.StateObject<number>,
	Text: Fusion.StateObject<string>,
}

return function(scope: Fusion.Scope, props: progressionBarProps, values: ProgressionBarValues, ImageID: string)
	local defaultProps = {
		Name = "ProgressionBar",
		Size = UDim2.fromScale(1, 0.5),
		Visible = true,
		[Children] = {

			Component.Frame(scope, {
				Name = "Track",
				Size = UDim2.fromScale(1, 1),
				Visible = true,
				BackgroundTransparency = 0,
				ClipsDescendants = true,

				[Children] = {

					Fill = Component.Frame(scope, {
						Name = "Fill",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Visible = true,
						ZIndex = 2,
						Size = scope:Computed(function(use)
							return UDim2.fromScale(use(values.Percent), 1)
						end),
						BackgroundTransparency = 0,

						[Children] = {
							Component.UIGradient(scope, {
								Color = props.Color or ColorSequence.new(Color3.new(0, 0.745098, 0.623529)),
								Rotation = 90,
								Enabled = true,
							}),
						},
					}),

					Background = Component.Frame(scope, {
						Name = "background",
						BackgroundColor3 = Color3.new(0.12549, 0.12549, 0.12549),
						Size = UDim2.fromScale(1, 1),
						ZIndex = 1,
						BackgroundTransparency = 0,
						Visible = true,
					}),

					Content = Component.Frame(scope, {
						Name = "Content",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						ZIndex = 3,
						Visible = true,

						[Children] = {
							Component.UIListLayout(scope, {
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0.02, 0),
							}),

							Component.UIPadding(scope, {
								PaddingLeft = UDim.new(0.02, 0),
							}),

							ImageLabel = Component.ImageLabel(scope, {
								Image = ImageID or "",
								Visible = true,
								Size = UDim2.fromScale(0.15, 0.7),
								BackgroundTransparency = 1,
								ScaleType = Enum.ScaleType.Fit,
								[Children] = Component.AspectRatio(scope, {}),
							}),

							Value = Component.TextLabel(scope, {
								LayoutOrder = 2,
								Name = "Value",
								Text = values.Text,
								TextSize = 34,
								Visible = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Center,
							}),
						},
					}),
				},
			}),
		},
	}

	return Component.CanvasGroup(scope, defaultProps)
end
