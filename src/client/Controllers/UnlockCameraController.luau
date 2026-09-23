local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)

local UnlockCameraController = Modux.Controller("UnlockCameraController")

UnlockCameraController:OnInit(function(self)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Parent = self.LocalPlayer.PlayerGui
	screenGui.Name = "ScreenGui"
	local TextButton = Instance.new("TextButton")
	TextButton.Parent = screenGui
	TextButton.Size = UDim2.fromScale(1, 1)
	TextButton.BackgroundTransparency = 1
	TextButton.Text = ""
	TextButton.Modal = false
	TextButton.Selectable = false
	TextButton.Interactable = false

	UserInputService.MouseIconEnabled = false

	ContextActionService:BindAction(
		"ModalButton",
		function(actionName: string, inputState: Enum.UserInputState, inputObject: InputObject)
			if inputState == Enum.UserInputState.Begin then
				local unlocked = not TextButton.Modal
				TextButton.Modal = unlocked

				UserInputService.MouseIconEnabled = unlocked
			end
		end,
		false,
		Enum.KeyCode.Q
	)
end)

UnlockCameraController:OnStart(function(self) end)

return UnlockCameraController
