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

return function(scope: Fusion.Scope, props: progressionBarProps, values: ProgressionBarValues)
	local defaultProps = {
		Name = "Healthbar",
		Size = UDim2.fromScale(1, 0.5),
		Visible = true,
		[Children] = {
			-- Track: fundo estático, corta o Fill que ultrapassar o tamanho
			Component.Frame(scope, {
				Name = "Track",
				Size = UDim2.fromScale(1, 1),
				Visible = true,
				BackgroundTransparency = 0,
				ClipsDescendants = true,

				[Children] = {
					-- Fill: encolhe/cresce de acordo com Percent (0 a 1)
					Fill = Component.Frame(scope, {
						Name = "Fill",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = scope:Computed(function(use)
							return UDim2.fromScale(use(values.Percent), 1)
						end),
						BackgroundTransparency = 0,

						[Children] = {
							Component.UIGradient(scope, {
								Color = props.Color or ColorSequence.new(Color3.new(0.003922, 0.67451, 0.415686)),
								Rotation = 90,
								Enabled = true,
							}),
						},
					}),

					-- Content: ícone + texto sobrepostos ao Fill, não afetados pelo Percent
					Content = Component.Frame(scope, {
						Name = "Content",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						ZIndex = 2,

						[Children] = {
							Component.UIListLayout(scope, {
								FillDirection = Enum.FillDirection.Horizontal,
							}),

							Image = Component.ImageLabel(scope, {
								Image = "rbxassetid://84000941134084",
								Visible = true,
								Size = UDim2.fromScale(0.15, 0.7),
								BackgroundTransparency = 1,
								ScaleType = Enum.ScaleType.Fit,
							}),

							Value = Component.TextLabel(scope, {
								LayoutOrder = 2,
								Name = "Value",
								Text = values.Text,
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
