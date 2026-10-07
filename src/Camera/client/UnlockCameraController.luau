--!strict
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const UnlockCameraController = Modux.Controller("UnlockCameraController", {
	Require = { "GameStateController", "InputController" },
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
	self.Forced = false :: boolean
	self.Manual = false :: boolean
	self.Menu = false :: boolean
end

function UnlockCameraController:SetUnlocked(unlocked: boolean)
	self.Button.Modal = unlocked
	UserInputService.MouseIconEnabled = unlocked
end

function UnlockCameraController:Refresh()
	self:SetUnlocked(self.Forced or self.Manual or self.Menu)
end

function UnlockCameraController:SetMenu(open: boolean)
	self.Menu = open
	self:Refresh()
end

UnlockCameraController:OnInit(function(self)
	self:Setup()

	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	self.Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self:SetUnlocked(false)
end)

UnlockCameraController:OnStart(function(self)
	self.Dependencies.GameStateController:Watch("FirstPerson", function(on: boolean)
		self.Forced = not on
		self:Refresh()
	end)

	const handle = self.Dependencies.InputController:Bind({
		Name = "UnlockCamera",
		Key = Enum.KeyCode.LeftAlt,
		Priority = 10,
	})

	handle.OnPress(function()
		self.Manual = true
		self:Refresh()
	end)

	handle.OnRelease(function()
		self.Manual = false
		self:Refresh()
	end)

	UserInputService.WindowFocusReleased:Connect(function()
		if self.Manual then
			self.Manual = false
			self:Refresh()
		end
	end)
end)

return UnlockCameraController
