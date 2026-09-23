local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)

export type TextAspectRatioProps = { [any]: any }

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
