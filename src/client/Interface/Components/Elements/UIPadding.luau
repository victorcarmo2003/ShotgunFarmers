local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local TableMerge = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.TableMerge)

export type AlignFlex = "None" | "Fill" | "SpaceAround" | "SpaceBetween" | "SpaceEvenly"

export type UIPaddingProps = {
	Name: string?,
	PaddingBottom: UDim?,
	PaddingLeft: UDim?,
	PaddingRight: UDim?,
	PaddingTop: UDim?,
}

return function(scope: Fusion.Scope, props: UIPaddingProps): UIPadding
	local defaultProps: UIPaddingProps = {
		Name = "UIPadding",
	}

	return scope:New("UIPadding")(TableMerge(defaultProps, props)) :: UIPadding
end
