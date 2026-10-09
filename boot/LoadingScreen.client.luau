--!strict
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

const READY_ATTRIBUTE = "LoadingDone"
const TIMEOUT = 25
const MIN_SECONDS = 1
const FADE_SECONDS = 0.5
const SPIN_SPEED = 240
const WHEEL_IMAGE = "rbxassetid://128841160920937"
const BACKGROUND = Color3.fromHex("#14281E")
const ACCENT = Color3.fromHex("#1F9F68")

ReplicatedFirst:RemoveDefaultLoadingScreen()

const player = Players.LocalPlayer
const playerGui = player:WaitForChild("PlayerGui")
const started = os.clock()

const gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000

const background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = BACKGROUND
background.Parent = gui

const gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new(BACKGROUND, Color3.new(0, 0, 0))
gradient.Parent = background

const title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.42)
title.Size = UDim2.fromScale(0.6, 0.12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.FredokaOne
title.Text = "SHOTGUN FARMERS"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.Parent = background

const stroke = Instance.new("UIStroke")
stroke.Color = ACCENT
stroke.Thickness = 3
stroke.Parent = title

const wheel = Instance.new("ImageLabel")
wheel.Name = "Wheel"
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.fromScale(0.5, 0.62)
wheel.Size = UDim2.fromScale(0.06, 0.06)
wheel.BackgroundTransparency = 1
wheel.ScaleType = Enum.ScaleType.Fit
wheel.Image = WHEEL_IMAGE
wheel.Parent = background

const ratio = Instance.new("UIAspectRatioConstraint")
ratio.AspectRatio = 1
ratio.Parent = wheel

const status = Instance.new("TextLabel")
status.Name = "Status"
status.AnchorPoint = Vector2.new(0.5, 0.5)
status.Position = UDim2.fromScale(0.5, 0.72)
status.Size = UDim2.fromScale(0.4, 0.04)
status.BackgroundTransparency = 1
status.Font = Enum.Font.FredokaOne
status.Text = "LOADING..."
status.TextColor3 = Color3.fromRGB(210, 210, 210)
status.TextScaled = true
status.Parent = background

gui.Parent = playerGui

const spin = RunService.RenderStepped:Connect(function(deltaTime: number)
	wheel.Rotation = (wheel.Rotation + SPIN_SPEED * deltaTime) % 360
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end

status.Text = "PREPARING THE FARM..."
while player:GetAttribute(READY_ATTRIBUTE) ~= true and os.clock() - started < TIMEOUT do
	task.wait(0.1)
end

const remaining = MIN_SECONDS - (os.clock() - started)
if remaining > 0 then
	task.wait(remaining)
end

const info = TweenInfo.new(FADE_SECONDS)
TweenService:Create(background, info, { BackgroundTransparency = 1 }):Play()
TweenService:Create(title, info, { TextTransparency = 1 }):Play()
TweenService:Create(stroke, info, { Transparency = 1 }):Play()
TweenService:Create(wheel, info, { ImageTransparency = 1 }):Play()
TweenService:Create(status, info, { TextTransparency = 1 }):Play()
task.wait(FADE_SECONDS)

spin:Disconnect()
gui:Destroy()
