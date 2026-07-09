local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local Enums = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.Enums)
local TableMerge = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.TableMerge)

local Children = Fusion.Children

export type textButtonProp = {
	OnClick: () -> ()?,
	OnEnter: () -> ()?,
	OnLeave: () -> ()?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,
	BackgroundColor3: Color3?,
	BackgroundTransparency: number?,
	Text: string?,
	LayoutOrder: number?,
	TextScaled: boolean?,
	TextColor: Color3?,
	TextSize: number?,
	FontFace: Font?,
	RichText: boolean?,
	Modal: boolean?,
} & { any }

return function(scope: Fusion.Scope, props: textButtonProp): TextButton
	local defaultProps: textButtonProp = {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.2, 0.1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Text = "Example",
		TextScaled = false,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 14,
		FontFace = Enums.Font.FredokaOne,
		RichText = false,
		Modal = false,
		[Children] = scope:New("UIStroke") {
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.2
		}

	}

	return scope:New("TextButton")(TableMerge(defaultProps, props)) :: TextButton
end
