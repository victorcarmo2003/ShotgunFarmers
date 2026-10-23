--!strict
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create
const source = Vide.source
const values = Vide.values

const DISPLAY_ORDER = 3
const TOUCH_GUI_WAIT = 15
const IDLE_COLOR = Color3.fromRGB(10, 10, 14)
const IDLE_TRANSPARENCY = 0.3
const IDLE_DARKEN = 0.6
const STROKE_LIGHTEN = 0.35
const ACTIVE_TRANSPARENCY = 0.1
const STROKE_COLOR = Color3.new(1, 1, 1)
const STROKE_TRANSPARENCY = 0.35
const STROKE_THICKNESS = 2
const PRESS_SCALE = 0.92
const SPRING_PERIOD = 0.1
const LABEL_RATIO = 0.3
const LABEL_MAX_TEXT = 26

const FIRE_X = 0.86
const FIRE_Y = 0.78
const FIRE_DIAMETER = 0.3
const SMALL_DIAMETER = 0.17
const ARC_RADIUS = 0.28
const JUMP_ANGLE = 110
const AIM_ANGLE = 150
const CROUCH_ANGLE = 195
const JUMP_COLOR = Color3.fromRGB(31, 159, 104)

const MENU_DIAMETER = 0.12
const MENU_GAP = 0.025
const MENU_MARGIN = 0.03
const MENU_LABEL_RATIO = 0.26
const MENU_MAX_TEXT = 18

const SKIN_TAG = "MobileSkin"

type TouchEntry = {
	Name: string,
	Menu: {
		Text: string,
		Color: Color3,
		Order: number,
		Toggle: boolean?,
		Visible: (() -> boolean)?,
	},
}

type Dispatcher = {
	Dispatch: (any, name: string, state: Enum.UserInputState) -> Enum.ContextActionResult,
	TouchAllowed: (any) -> boolean,
	TouchMenus: Vide.Source<{ TouchEntry }>,
}

type Press = {
	Pressed: Vide.Source<boolean>,
	Filled: () -> boolean,
	Began: (input: InputObject) -> (),
}

type ButtonSpec = {
	Name: string,
	Text: string,
	Angle: number?,
	Diameter: number,
	Color: Color3,
	Toggle: boolean,
}

const BUTTONS: { ButtonSpec } = {
	{ Name = "Fire", Text = "FIRE", Angle = nil, Diameter = FIRE_DIAMETER, Color = Color3.fromRGB(226, 75, 60), Toggle = false },
	{ Name = "Aim", Text = "AIM", Angle = AIM_ANGLE, Diameter = SMALL_DIAMETER, Color = Color3.fromRGB(0, 149, 255), Toggle = true },
	{ Name = "Crouch", Text = "CROUCH", Angle = CROUCH_ANGLE, Diameter = SMALL_DIAMETER, Color = Color3.fromRGB(255, 174, 0), Toggle = false },
}

local function currentViewport(): Vector2
	const camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

local function positionFor(viewport: Vector2, angle: number?): UDim2
	const centerX = viewport.X * FIRE_X
	const centerY = viewport.Y * FIRE_Y
	if not angle then
		return UDim2.fromOffset(centerX, centerY)
	end

	const radians = math.rad(angle)
	return UDim2.fromOffset(
		centerX + ARC_RADIUS * viewport.Y * math.cos(radians),
		centerY - ARC_RADIUS * viewport.Y * math.sin(radians)
	)
end

local function sizeFor(viewport: Vector2, diameter: number): UDim2
	return UDim2.fromOffset(diameter * viewport.Y, diameter * viewport.Y)
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function idleColor(accent: Color3): Color3
	return accent:Lerp(Color3.new(0, 0, 0), IDLE_DARKEN)
end

local function circleFace(color: Color3, label: string, ratio: number?, maxText: number?): { Instance }
	return {
		create("UICorner")({
			CornerRadius = UDim.new(0.5, 0),
		}),

		CreateRaw("UIStroke")({
			Color = color:Lerp(Color3.new(1, 1, 1), STROKE_LIGHTEN),
			Transparency = STROKE_TRANSPARENCY,
			Thickness = STROKE_THICKNESS,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),

		create("TextLabel")({
			Name = "Label",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.78, ratio or LABEL_RATIO),
			BackgroundTransparency = 1,
			FontFace = Fonts.FredokaOne,
			Text = label,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,

			CreateRaw("UITextSizeConstraint")({
				MaxTextSize = maxText or LABEL_MAX_TEXT,
			}),
		}),
	}
end

local function pressState(name: string, toggle: boolean, dispatcher: Dispatcher): Press
	const pressed = source(false)
	const active = source(false)
	local touch: InputObject? = nil

	const press = function()
		pressed(true)
		if toggle then
			const next = not active()
			active(next)
			dispatcher:Dispatch(name, if next then Enum.UserInputState.Begin else Enum.UserInputState.End)
		else
			dispatcher:Dispatch(name, Enum.UserInputState.Begin)
		end
	end

	const release = function()
		pressed(false)
		if not toggle then
			dispatcher:Dispatch(name, Enum.UserInputState.End)
		end
	end

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if touch ~= nil and input == touch then
			touch = nil
			release()
		end
	end)

	return {
		Pressed = pressed,
		Filled = function(): boolean
			return pressed() or active()
		end,
		Began = function(input: InputObject)
			if touch == nil and isPress(input) then
				touch = input
				press()
			end
		end,
	}
end

local function controlButton(spec: ButtonSpec, dispatcher: Dispatcher, viewport: () -> Vector2): TextButton
	const state = pressState(spec.Name, spec.Toggle, dispatcher)
	const filled = state.Filled

	return create("TextButton")({
		Name = spec.Name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = function()
			return positionFor(viewport(), spec.Angle)
		end,
		Size = function()
			return sizeFor(viewport(), spec.Diameter)
		end,
		BackgroundColor3 = function()
			return if filled() then spec.Color else idleColor(spec.Color)
		end,
		BackgroundTransparency = function()
			return if filled() then ACTIVE_TRANSPARENCY else IDLE_TRANSPARENCY
		end,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",

		InputBegan = state.Began,

		CreateRaw("UIScale")({
			Scale = Vide.spring(function()
				return if state.Pressed() then PRESS_SCALE else 1
			end, SPRING_PERIOD, 1),
		}),

		circleFace(spec.Color, spec.Text),
	})
end

local function menuButton(entry: TouchEntry, dispatcher: Dispatcher, viewport: () -> Vector2): TextButton
	const menu = entry.Menu
	const state = pressState(entry.Name, menu.Toggle == true, dispatcher)

	return create("TextButton")({
		Name = entry.Name,
		LayoutOrder = menu.Order,
		Size = function()
			return sizeFor(viewport(), MENU_DIAMETER)
		end,
		Visible = menu.Visible or true,
		BackgroundColor3 = function()
			return if state.Filled() then menu.Color else idleColor(menu.Color)
		end,
		BackgroundTransparency = function()
			return if state.Filled() then ACTIVE_TRANSPARENCY else IDLE_TRANSPARENCY
		end,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",

		InputBegan = state.Began,

		CreateRaw("UIScale")({
			Scale = Vide.spring(function()
				return if state.Pressed() then PRESS_SCALE else 1
			end, SPRING_PERIOD, 1),
		}),

		circleFace(menu.Color, menu.Text, MENU_LABEL_RATIO, MENU_MAX_TEXT),
	})
end

local function menuBar(dispatcher: Dispatcher, viewport: () -> Vector2): Frame
	return create("Frame")({
		Name = "Menus",
		AnchorPoint = Vector2.new(1, 0),
		Position = function()
			const size = viewport()
			const inset = GuiService:GetGuiInset()
			return UDim2.fromOffset(size.X - MENU_MARGIN * size.Y, inset.Y + MENU_MARGIN * size.Y)
		end,
		Size = function()
			const size = viewport()
			return UDim2.fromOffset(size.X * 0.5, MENU_DIAMETER * size.Y)
		end,
		BackgroundTransparency = 1,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = function()
				return UDim.new(0, MENU_GAP * viewport().Y)
			end,
		}),

		values(function()
			return dispatcher.TouchMenus()
		end, function(entry: TouchEntry)
			return menuButton(entry, dispatcher, viewport)
		end),
	})
end

local function addFace(target: GuiObject, color: Color3, transparency: number, accent: Color3?)
	if target:FindFirstChild(SKIN_TAG) then
		return
	end

	const corner = Instance.new("UICorner")
	corner.Name = SKIN_TAG
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = target

	const stroke = Instance.new("UIStroke")
	stroke.Color = if accent then accent:Lerp(Color3.new(1, 1, 1), STROKE_LIGHTEN) else STROKE_COLOR
	stroke.Transparency = STROKE_TRANSPARENCY
	stroke.Thickness = STROKE_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = target

	target.BackgroundColor3 = color
	target.BackgroundTransparency = transparency
end

local function clearImage(image: GuiObject)
	if image:IsA("ImageLabel") or image:IsA("ImageButton") then
		if image.Image ~= "" then
			image.Image = ""
		end
	end
end

local function styleJump(button: ImageButton)
	const apply = function()
		const viewport = currentViewport()
		const inset = GuiService:GetGuiInset()
		const target = positionFor(viewport, JUMP_ANGLE)
		const position = UDim2.fromOffset(target.X.Offset - inset.X, target.Y.Offset - inset.Y)
		const size = sizeFor(viewport, SMALL_DIAMETER)
		clearImage(button)
		if button.AnchorPoint ~= Vector2.new(0.5, 0.5) then
			button.AnchorPoint = Vector2.new(0.5, 0.5)
		end
		if button.Position ~= position then
			button.Position = position
		end
		if button.Size ~= size then
			button.Size = size
		end
	end

	addFace(button, idleColor(JUMP_COLOR), IDLE_TRANSPARENCY, JUMP_COLOR)

	if not button:FindFirstChild("JumpLabel") then
		const label = Instance.new("TextLabel")
		label.Name = "JumpLabel"
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(0.78, LABEL_RATIO)
		label.BackgroundTransparency = 1
		label.FontFace = Fonts.FredokaOne
		label.Text = "JUMP"
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Active = false
		label.Parent = button

		const constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = LABEL_MAX_TEXT
		constraint.Parent = label
	end

	button.InputBegan:Connect(function(input: InputObject)
		if isPress(input) then
			button.BackgroundColor3 = JUMP_COLOR
			button.BackgroundTransparency = ACTIVE_TRANSPARENCY
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if isPress(input) then
			button.BackgroundColor3 = idleColor(JUMP_COLOR)
			button.BackgroundTransparency = IDLE_TRANSPARENCY
		end
	end)

	apply()
	for _, property in { "Position", "Size", "Image", "AnchorPoint" } do
		button:GetPropertyChangedSignal(property):Connect(apply)
	end

	const camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	end
end

local function styleThumbstick(frame: GuiObject)
	for _, descendant in frame:GetDescendants() do
		if descendant:IsA("ImageLabel") then
			clearImage(descendant)
			const isStick = string.find(string.lower(descendant.Name), "stick") ~= nil
			addFace(descendant, if isStick then Color3.new(1, 1, 1) else IDLE_COLOR, if isStick then 0.25 else IDLE_TRANSPARENCY)
			descendant:GetPropertyChangedSignal("Image"):Connect(function()
				clearImage(descendant)
			end)
		end
	end

	frame.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("ImageLabel") then
			clearImage(descendant)
			addFace(descendant, IDLE_COLOR, IDLE_TRANSPARENCY)
		end
	end)
end

local function skinTouchGui(playerGui: PlayerGui)
	const touchGui = playerGui:WaitForChild("TouchGui", TOUCH_GUI_WAIT)
	const controls = if touchGui then touchGui:WaitForChild("TouchControlFrame", TOUCH_GUI_WAIT) else nil
	if not controls then
		return
	end

	const jump = controls:WaitForChild("JumpButton", TOUCH_GUI_WAIT)
	if jump and jump:IsA("ImageButton") then
		styleJump(jump)
	end

	for _, name in { "ThumbstickFrame", "DynamicThumbstickFrame" } do
		const frame = controls:FindFirstChild(name)
		if frame and frame:IsA("GuiObject") then
			styleThumbstick(frame)
		end
	end
end

const MobileControls = {}

function MobileControls.Mount(dispatcher: Dispatcher)
	const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

	const viewport = source(currentViewport())
	const camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			viewport(currentViewport())
		end)
	end

	Vide.mount(function()
		const buttons: { Instance } = {}
		for _, spec in BUTTONS do
			table.insert(buttons, controlButton(spec, dispatcher, viewport))
		end
		table.insert(buttons, menuBar(dispatcher, viewport))

		return create("ScreenGui")({
			Name = "MobileControlsUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = DISPLAY_ORDER,
			Enabled = function()
				return dispatcher:TouchAllowed()
			end,

			buttons,
		})
	end, playerGui)

	task.spawn(function()
		skinTouchGui(playerGui)
	end)
end

return MobileControls
