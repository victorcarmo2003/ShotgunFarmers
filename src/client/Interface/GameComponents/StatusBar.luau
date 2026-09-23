local StarterPlayer = game:GetService("StarterPlayer")
local ProgressionBar = require(script.Parent.ProgressionBar)
local Components = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Components)
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)

local localPlayer = game.Players.LocalPlayer
local Children = Fusion.Children

return function(scope: Fusion.Scope, Values)
	local shieldValues = {
		Percent = Values.Armor,
		Text = scope:Computed(function(use)
			return `{math.floor(use(Values.Armor) * 100)}%`
		end),
	}
	local healthValues = {
		Percent = Values.Health,
		Text = scope:Computed(function(use)
			return `{math.floor(use(Values.Health) * 100)}%`
		end),
	}

	return Components.CanvasGroup(scope, {
		Visible = true,
		Size = UDim2.fromScale(0.3, 0.2),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.15, 0.895),

		[Children] = {
			UIListLayout = Components.UIListLayout(scope, {
				FillDirection = "Horizontal",
				Padding = UDim.new(0.05),
				Wraps = true,
			}),
			UIPadding = Components.UIPadding(scope, {
				PaddingLeft = UDim.new(0.05, 0),
			}),
			PlayerImage = Components.ImageLabel(scope, {
				LayoutOrder = 1,
				Size = UDim2.fromScale(0.2, 0.45),
				Name = "PlayerImage",
				Visible = true,
				Image = Values.PlayerImage,
				BackgroundColor3 = Color3.new(0.12549, 0.12549, 0.12549),
			}),
			StatusFrame = Components.Frame(scope, {
				LayoutOrder = 2,
				Name = "PlayerStatus",
				Visible = true,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(0.7, 0.4),
				[Children] = {
					UIGrid = Components.UIGridLayout(scope, {
						CellSize = UDim2.fromScale(1, 0.5),
					}),
					ShieldBar = ProgressionBar(scope, {
						LayoutOrder = 1,
						Name = "ShieldBar",
						Visible = true,
						Color = ColorSequence.new(Color3.new(0, 0.411765, 0.886275)),
					}, shieldValues, "rbxassetid://84000941134084"),
					HealthBar = ProgressionBar(scope, {
						LayoutOrder = 2,
						Name = "HealthBar",
						Visible = true,
						Color = ColorSequence.new(Color3.new(0, 0.619608, 0.411765)),
					}, healthValues, "rbxassetid://98924504834257"),
				},
			}),

			TextLabel = Components.TextLabel(scope, {
				LayoutOrder = 0,
				Text = localPlayer.DisplayName,
				Size = UDim2.fromScale(1, 0.3),
				TextSize = 42,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		},
	})
end
