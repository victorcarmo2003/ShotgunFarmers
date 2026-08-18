local StarterPlayer = game:GetService("StarterPlayer")
local Components = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Components)
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)

export type GunNameLabelValues = {
	Text: Fusion.StateObject<string> | string,
}

return function(scope: Fusion.Scope, Values: GunNameLabelValues)
	return Components.TextLabel(scope, {
		Position = UDim2.fromScale(0.5, 0.1),
		TextSize = 36,
		Text = Values.Text,
		Name = "GunNameLabel",
	})
end
