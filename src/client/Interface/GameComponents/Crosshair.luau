local StarterPlayer = game:GetService("StarterPlayer")
local Component = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Components)
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)

local Children = Fusion.Children

local MARK_LENGTH = 10
local MARK_THICKNESS = 3
-- Distância (px) de cada marca até o centro -- MIN quando SpreadRatio = 0 (spread
-- efetivo mínimo, mirando), MAX quando SpreadRatio = 1 (hip-fire). Ajustável: perto
-- demais e as 4 marcas colam umas nas outras, longe demais e "Default" e "Spread"
-- ficam parecidos até no hip-fire.
local MIN_GAP = 6
local MAX_GAP = 16

export type CrosshairValues = {
	-- "Spread" | "Default" | nil (nil cai pro Default) -- GunData.AimType (Guns.luau).
	AimType: Fusion.StateObject<string?> | string?,
	-- 1 = spread normal (parado, sem mirar); >1 enquanto se move, <1 enquanto mira -- ver
	-- InterfaceController, combina GameSettings.MovingSpreadMultiplier e AimSpreadMultiplier.
	SpreadRatio: Fusion.StateObject<number> | number,
	-- Enquanto mira, a crosshair inteira some (ArmsController.IsAimingValue) -- olhando
	-- pela mira da arma não faz sentido mostrar reticle por cima.
	IsAiming: Fusion.StateObject<boolean> | boolean,
}

-- Uma marca em "T com a ponta curva": um traço reto voltado pro centro, arredondado
-- na ponta (UICorner só suporta raio uniforme no Roblox, então a marca fica com as
-- duas pontas curvas -- uma capsula -- em vez de só a de fora; ajustar depois no
-- Studio se quiser só uma ponta reta). `direction` decide de que lado da tela ela
-- fica e se o traço é vertical (Top/Bottom) ou horizontal (Left/Right).
local function spreadMark(scope: Fusion.Scope, gap: Fusion.StateObject<number>, direction: "Top" | "Bottom" | "Left" | "Right")
	local isVertical = direction == "Top" or direction == "Bottom"
	local sign = if direction == "Top" or direction == "Left" then -1 else 1

	local position = scope:Computed(function(use)
		local offset = use(gap) * sign
		if isVertical then
			return UDim2.fromOffset(0, offset)
		end
		return UDim2.fromOffset(offset, 0)
	end)

	return Component.Frame(scope, {
		Name = direction,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = if isVertical
			then UDim2.fromOffset(MARK_THICKNESS, MARK_LENGTH)
			else UDim2.fromOffset(MARK_LENGTH, MARK_THICKNESS),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Visible = true,
		[Children] = {
			Component.UICorner(scope, { CornerRadius = UDim.new(1, 0) }),
		},
	})
end

-- Mira "Default": um "+" estático, sem reagir a spread nenhum.
local function plusCrosshair(scope: Fusion.Scope)
	return {
		Horizontal = Component.Frame(scope, {
			Name = "Horizontal",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(MARK_LENGTH * 2, MARK_THICKNESS),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			Visible = true,
		}),
		Vertical = Component.Frame(scope, {
			Name = "Vertical",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(MARK_THICKNESS, MARK_LENGTH * 2),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			Visible = true,
		}),
	}
end

return function(scope: Fusion.Scope, values: CrosshairValues)
	-- Spring em cima do gap (não no Position de cada marca direto) -- as 4 marcas
	-- compartilham a mesma mola, então abrem/fecham em uníssono ao trocar de mirar.
	local gap = scope:Spring(
		scope:Computed(function(use)
			return MIN_GAP + (MAX_GAP - MIN_GAP) * use(values.SpreadRatio)
		end),
		24,
		1
	)

	local isSpreadable = scope:Computed(function(use)
		return use(values.AimType) == "Spread"
	end)

	return Component.Frame(scope, {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use)
			return not use(values.IsAiming)
		end),

		[Children] = {
			SpreadMarks = Component.Frame(scope, {
				Name = "SpreadMarks",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				Visible = isSpreadable,
				[Children] = {
					Top = spreadMark(scope, gap, "Top"),
					Bottom = spreadMark(scope, gap, "Bottom"),
					Left = spreadMark(scope, gap, "Left"),
					Right = spreadMark(scope, gap, "Right"),
				},
			}),

			Plus = Component.Frame(scope, {
				Name = "Plus",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use)
					return not use(isSpreadable)
				end),
				[Children] = plusCrosshair(scope),
			}),
		},
	})
end
