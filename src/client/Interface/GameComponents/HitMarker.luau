local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Component = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Components)
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)

local Children = Fusion.Children

local MARK_LENGTH = 24
local MARK_THICKNESS = 3
local FADE_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type HitMarkerValues = {
	-- Contador (HitController.HitMarkerTrigger) -- só o valor em si não importa, apenas
	-- a MUDANÇA dispara o flash (um acerto confirmado pelo server).
	Trigger: Fusion.StateObject<number>,
}

-- Um traço do X, rotacionado 45/-45 a partir do centro.
local function mark(scope: Fusion.Scope, name: string, rotation: number)
	return Component.Frame(scope, {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(MARK_LENGTH, MARK_THICKNESS),
		Rotation = rotation,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Visible = true,
	})
end

return function(scope: Fusion.Scope, values: HitMarkerValues)
	local marks = { mark(scope, "Mark1", 45), mark(scope, "Mark2", -45) }
	-- BackgroundTransparency destes marks é controlado por TweenService, fora do grafo
	-- reativo do Fusion (igual ao FOVController) -- é um efeito de disparo único, não
	-- estado persistente, então não faz sentido modelar como Computed/Spring.
	local activeTweens: { [Frame]: Tween } = {}

	scope:Observer(values.Trigger):onChange(function()
		for _, markFrame in marks do
			local existingTween = activeTweens[markFrame]
			if existingTween then
				existingTween:Cancel()
				existingTween:Destroy()
			end

			markFrame.BackgroundTransparency = 0
			local tween = TweenService:Create(markFrame, FADE_TWEEN, { BackgroundTransparency = 1 })
			activeTweens[markFrame] = tween
			tween:Play()
		end
	end)

	return Component.Frame(scope, {
		Name = "HitMarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		BackgroundColor3 = Color3.new(1, 0, 0),
		Visible = true,
		[Children] = marks,
	})
end
