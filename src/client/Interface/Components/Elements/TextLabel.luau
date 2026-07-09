local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local Enums = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.Enums)
local TableMerge = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.TableMerge)

local Children = Fusion.Children

export type textLabelProp = {
	OnEnter: () -> ()?,
	OnLeave: () -> ()?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,
	BackgroundColor3: Color3?,
	BackgroundTransparency: number?,
	Text: string?,
	LayoutOrder: number?,
	TextXAlignment: Enum.TextXAlignment?,
	TextYAlignment: Enum.TextYAlignment?,
	TextScaled: boolean?,
	TextColor: Color3?,
	TextSize: number?,
	FontFace: Font?,
	RichText: boolean?,
} & { any }

return function(scope: Fusion.Scope, props: textLabelProp): TextLabel
	local defaultProps: textLabelProp = {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.2, 0.1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Text = "Example",
		TextScaled = false,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		FontFace = Enums.Font.FredokaOne,
		RichText = false,
	}

	return scope:New("TextLabel")(TableMerge(defaultProps, props)) :: TextLabel
end
