--!strict
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const UnlockCameraController = Modux.Controller("UnlockCameraController", {
	Require = { "InputController" },
	Priority = 400,
})

function UnlockCameraController:Setup()
	const gui = Instance.new("ScreenGui")
	gui.Name = "UnlockCamera"

	gui.ResetOnSpawn = false

	const button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Modal = false
	button.Selectable = false
	button.Interactable = false
	button.Parent = gui

	self.Gui = gui :: ScreenGui
	self.Button = button :: TextButton
end

function UnlockCameraController:SetUnlocked(unlocked: boolean)
	self.Button.Modal = unlocked
	UserInputService.MouseIconEnabled = unlocked
end

UnlockCameraController:OnInit(function(self)
	self:Setup()

	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	self.Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self:SetUnlocked(false)
end)

UnlockCameraController:OnStart(function(self)
	self.Dependencies.InputController
		:Bind({ Name = "UnlockCamera", Key = Enum.KeyCode.Q, Priority = 10 })
		.OnPress(function()
			self:SetUnlocked(not self.Button.Modal)
		end)
end)

return UnlockCameraController
