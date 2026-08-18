local StarterPlayer = game:GetService("StarterPlayer")
local Components = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Components)

return function(scope)
	return Components.TextLabel(scope, {
		Position = UDim2.fromScale(0.5, 0.1),
		TextSize = 36,
		Text = "Loading...",
		Name = "TimerLabel",
	})
end
