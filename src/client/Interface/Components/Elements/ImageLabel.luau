local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local TableMerge = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.TableMerge)

export type imageLabelProp = {
	OnEnter: () -> ()?,
	OnLeave: () -> ()?,
	Active: boolean?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,
	BackgroundTransparency: number?,
	BackgroundColor3: Color3?,
	Interactable: boolean?,
	LayoutOrder: number?,
	Visible: boolean?,
	ZIndex: number?,
	ClipsDescendants: boolean?,
	Image: string?,
	ImageColor3: Color3?,
	ImageContent: string?,
	ImageTransparency: number?,
	ResampleMode: Enum.ResamplerMode?,
	ScaleType: Enum.ScaleType?,
	Selectable: boolean?,
} & { any }

local defaultProps: imageLabelProp = {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Active = true,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(.25, .25),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0,
	Visible = true,
	Selectable = true,
}

return function(scope: Fusion.Scope, props: imageLabelProp): ImageLabel
	return scope:New("ImageLabel")(TableMerge(defaultProps, props)) :: ImageLabel
end
