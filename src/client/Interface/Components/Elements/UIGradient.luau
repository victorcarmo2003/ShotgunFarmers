local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local TableMerge = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.TableMerge)

export type AlignFlex = "None" | "Fill" | "SpaceAround" | "SpaceBetween" | "SpaceEvenly"

export type UIGradientProps = {
	Color: Color3? | ColorSequence,
	Enabled: boolean?,
	Offset: UDim?,
	Rotation: number?,
	Transparency: number?,
	Name: string?,
}

return function(scope: Fusion.Scope, props: UIGradientProps): UIGradient
	local defaultProps: UIGradientProps = {
		Name = "UIGradient",
		Enabled = true,
	}

	return scope:New("UIGradient")(TableMerge(defaultProps, props)) :: UIGradient
end
