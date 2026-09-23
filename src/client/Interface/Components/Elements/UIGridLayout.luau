local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local TableMerge = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.TableMerge)

export type UIGridLayoutProp = {
	CellPadding: UDim2?,
	CellSize: UDim2?,
	Name: string?,
	FillDirection: Enum.FillDirection?,
	FillDirectionMaxCells: number?,
	SortOrder: Enum.SortOrder?,
	StartCorner: Enum.StartCorner?,
	HorizontalAlignment: Enum.HorizontalAlignment?,
	VerticalAlignment: Enum.VerticalAlignment?,
} & { any }

return function(scope: Fusion.Scope, props: UIGridLayoutProp): UIGridLayout
	local defaultProps: UIGridLayoutProp = {
		Name = "UIGridLayout",
		CellSize = UDim2.new(0.25,0.25),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}

	return scope:New("UIGridLayout")(TableMerge(defaultProps, props)) :: UIGridLayout
end
