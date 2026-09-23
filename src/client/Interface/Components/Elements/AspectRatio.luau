local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local TableMerge = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.TableMerge)

export type AspectRatioProps = {
	Name: string?,
	AspectRatio: number?,
	AspectType: Enum.AspectType?,
	DominantAxis: Enum.DominantAxis?,
	Enabled: boolean?,
} & { any }

return function(scope: Fusion.Scope, props: AspectRatioProps): UIAspectRatioConstraint
	local defaultProps: AspectRatioProps = {
		Name = "AspectRatio",
		AspectRatio = 1,
		AspectType = Enum.AspectType.FitWithinMaxSize,
		DominantAxis = Enum.DominantAxis.Width,
	}

	return scope:New("UIAspectRatioConstraint")(TableMerge(defaultProps, props)) :: UIAspectRatioConstraint
end
