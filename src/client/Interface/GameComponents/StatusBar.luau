local StarterPlayer = game:GetService("StarterPlayer")
local ProgressionBar = require(script.Parent.ProgressionBar)
local Components = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Components)
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)

local Children = Fusion.Children

return function(scope: Fusion.Scope)
	-- TODO: substituir por Values reais do VitalController quando a rede estiver ligada
	local shieldValues = {
		Percent = scope:Value(1),
		Text = scope:Value("100%"),
	}
	local healthValues = {
		Percent = scope:Value(1),
		Text = scope:Value("100%"),
	}

	return Components.CanvasGroup(scope, {
		Visible = true,
		Size = UDim2.fromScale(0.25, 0.1),
		BackgroundTransparency = 1,

		[Children] = {
			UIListLayout = Components.UIListLayout(scope, {
				FillDirection = "Horizontal",
				Padding = UDim.new(0.05),
			}),
			UIPadding = Components.UIPadding(scope, {
				PaddingLeft = UDim.new(0.05, 0),
			}),
			PlayerImage = Components.ImageLabel(scope, {
				LayoutOrder = 1,
				Size = UDim2.fromScale(0.2, 0.8),
				Name = "PlayerImage",
				Visible = true,
			}),
			StatusFrame = Components.Frame(scope, {
				LayoutOrder = 2,
				Name = "PlayerStatus",
				Visible = true,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(0.65, 0.8),

				[Children] = {
					UIGrid = Components.UIGridLayout(scope, {
						CellSize = UDim2.fromScale(1, 0.5),
					}),
					ShieldBar = ProgressionBar(scope, {
						LayoutOrder = 1,
						Name = "ShieldBar",
					}, shieldValues),
					HealthBar = ProgressionBar(scope, {
						LayoutOrder = 2,
						Name = "HealthBar",
					}, healthValues),
				},
			}),
		},
	})
end
