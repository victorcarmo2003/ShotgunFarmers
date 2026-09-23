local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local TableMerge = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.TableMerge)

export type imageButtonProp = {
	OnClick: () -> ()?,
	OnEnter: () -> ()?,
	OnLeave: () -> ()?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,
	LayoutOrder: number?,
	BackgroundColor3: Color3?,
	BackgroundTransparency: number?,
	Modal: boolean?,
} & {any}

local defaultProps: imageButtonProp = {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.2, 0.1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	Modal = false,
}

return function(scope: Fusion.Scope, props: imageButtonProp): ImageButton
	return scope:New("ImageButton")(TableMerge(defaultProps, props)) :: ImageButton
end
