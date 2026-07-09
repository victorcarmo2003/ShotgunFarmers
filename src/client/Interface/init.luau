local Components = require(script.Components)
local Modux = require(game.ReplicatedStorage.Shared.Modux)

export type MainGuiType = {
	TimerLabel: TextLabel,
} & ScreenGui

local Fusion = require(script.Fusion)
local StatusBar = require(script.GameComponents.StatusBar)
local scoped, Children, OnEvent = Fusion.scoped, Fusion.Children, Fusion.OnEvent
local scope = scoped(Fusion)

local InterfaceController = Modux.Controller("InterfaceController")

InterfaceController:OnInit(function(self)
	self.Scope = scope :: Fusion.Scope
end)

InterfaceController:OnStart(function(self)
	local textButton = Components.TextLabel(self.Scope, {
		Position = UDim2.fromScale(0.5, 0.1),
		Text = "Loading...",
		Name = "TimerLabel",
	})

	local screenGui = Components.ScreenGui(self.Scope, {
		Name = "FusionGUI",
		[Children] = {
			TextButton = textButton,
			StatusBar(self.Scope),
		},
	})

	screenGui.Parent = self.LocalPlayer.PlayerGui

	self.ScreenGui = screenGui :: MainGuiType
end)

return InterfaceController
