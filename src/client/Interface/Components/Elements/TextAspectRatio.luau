local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)

export type TextAspectRatioProps = { [any]: any }

-- Diferente dos outros Elements, este não cria uma instância separada:
-- ele decora as props de um TextLabel/TextButton para que o próprio Size
-- vire um quadrado (Ratio:1 por padrão) acompanhando o TextSize em tempo
-- real, via Fusion.Out. Uso: Components.TextButton(scope, Components.TextAspectRatio(scope, { TextSize = 32, ... }))
return function(scope: Fusion.Scope, props: TextAspectRatioProps, ratio: number?): TextAspectRatioProps
	local Ratio = ratio or 1
	local initialTextSize = (props.TextSize :: number?) or 14
	local textSize = scope:Value(initialTextSize)

	props[Fusion.Out("TextSize")] = textSize
	props.Size = scope:Computed(function(use)
		local size = use(textSize)
		return UDim2.fromOffset(size * Ratio, size)
	end)

	return props
end
