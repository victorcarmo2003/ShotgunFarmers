local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local TableMerge = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.TableMerge)

export type UICornerProps = {
	Name: string?,
	CornerRadius: UDim?,
	BottomLeftRadius: UDim?,
	BottomRightRadius: UDim?,
	TopLeftRadius: UDim?,
	TopRightRadius: UDim?,
	Archivable: boolean?,
	Enabled: boolean?,
}

return function(scope: Fusion.Scope, props: UICornerProps): UICorner
	local defaultProps: UICornerProps = {
		Name = "UICorner",
		CornerRadius = UDim.new(0.1),
	}
	return scope:New("UICorner")(TableMerge(defaultProps, props)) :: UICorner
end
