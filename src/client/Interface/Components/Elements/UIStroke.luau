local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local TableMerge = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.TableMerge)

export type AlignFlex = "None" | "Fill" | "SpaceAround" | "SpaceBetween" | "SpaceEvenly"

export type UIStrokeProps = {
	Name: string?,
	ApplyStrokeMode: Enum.ApplyStrokeMode?,
	BorderOffset: UDim?,
	BorderStrokePosition: Enum.BorderStrokePosition?,
	StrokeSizingMode: Enum.ApplyStrokeMode?,
	Color: Color3?,
	LineJoinMode: Enum.LineJoinMode?,
	Thickness: number?,
	Transparency: number?,
	ZIndex: number?,
	Archivable: boolean?,
	Enabled: boolean?,
}

return function(scope: Fusion.Scope, props: UIStrokeProps): UIStroke
	local defaultProps: UIStrokeProps = {
		Name = "UIStroke",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = 0.2,
	}
	return scope:New("UIStroke")(TableMerge(defaultProps, props)) :: UIStroke
end
