local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local TableMerge = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.TableMerge)

export type AlignFlex = "None" | "Fill" | "SpaceAround" | "SpaceBetween" | "SpaceEvenly"

export type UIListLayoutProp = {
	Padding: UDim?,
	Name: string?,
	FillDirection: Enum.FillDirection?,
	SortOrder: Enum.SortOrder?,
	Wraps: boolean?,
	HorizontalAlignment: Enum.HorizontalAlignment?,
	HorizontalFlex: AlignFlex?,
	VerticalAlignment: Enum.VerticalAlignment?,
	VerticalFlex: AlignFlex?,
} & { any }

return function(scope: Fusion.Scope, props: UIListLayoutProp): UIListLayout
	local defaultProps: UIListLayoutProp = {
		Padding = UDim.new(0, 0),
		Name = "UIList",
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Wraps = false,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		HorizontalFlex = "None",
		VerticalAlignment = Enum.VerticalAlignment.Center,
		VerticalFlex = "None",
	}

	return scope:New("UIListLayout")(TableMerge(defaultProps, props)) :: UIListLayout
end
