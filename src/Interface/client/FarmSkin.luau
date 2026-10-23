--!strict
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Palette = require(script.Parent.FarmPalette)
local FarmVFX = require(script.Parent.FarmVFX)

local MENU_GUIS = {
	LobbyUI = true,
	LobbyScreensUI = true,
	OptionsUI = true,
	PracticeUI = true,
	VoteUI = true,
	MatchSummaryUI = true,
	PartyInviteUI = true,
	RoomCodeUI = true,
	AnnouncementUI = true,
	DeathScreenUI = true,
}
local POP_GUIS = {
	LobbyScreensUI = true,
	OptionsUI = true,
	PracticeUI = true,
	VoteUI = true,
	MatchSummaryUI = true,
	PartyInviteUI = true,
	AnnouncementUI = true,
}

type SkinState = {
	origTransparency: number,
	kind: string,
	color: Color3,
	base: Color3,
	glow: boolean,
	key: string?,
	stroke: UIStroke?,
}

local weak = { __mode = "k" }
local state: { [GuiObject]: SkinState } = setmetatable({}, weak) :: any
local lastBg: { [GuiObject]: Color3 } = setmetatable({}, weak) :: any
local lastText: { [GuiObject]: Color3 } = setmetatable({}, weak) :: any
local hooked: { [Instance]: boolean } = setmetatable({}, weak) :: any

local FarmSkin = {}

local function viewport(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1920, 1080)
end

local function scale(): number
	return math.max(viewport().Y / 1080, 0.45)
end

local function same(a: Color3, b: Color3?): boolean
	return b ~= nil and a:ToHex() == b:ToHex()
end

local function darken(c: Color3, k: number): Color3
	return c:Lerp(Palette.Ink, k)
end

local function remapBg(color: Color3): (Color3, string)
	local h, s, v = color:ToHSV()
	if s < 0.2 then
		if v < 0.12 then
			return Palette.WoodDark, "panel"
		elseif v < 0.4 then
			return Palette.Soil:Lerp(Palette.Wood, math.clamp((v - 0.12) / 0.28, 0, 1) * 0.7), "dark"
		elseif v < 0.75 then
			return Palette.Wood, "wood"
		end
		return Palette.Cream, "cream"
	end

	local deg = h * 360
	local base
	if deg < 18 or deg >= 335 then
		base = Palette.Barn
	elseif deg < 48 then
		base = Palette.Pumpkin
	elseif deg < 70 then
		base = Palette.Wheat
	elseif deg < 175 then
		base = Palette.Leaf
	elseif deg < 255 then
		base = Palette.Sky
	else
		base = Palette.Grape
	end
	return darken(base, math.clamp((0.6 - v) * 0.9, 0, 0.45)), "color"
end

local function remapText(c: Color3): Color3
	local h, s, v = c:ToHSV()
	if s < 0.15 and v > 0.85 then
		return Palette.TextWhite
	end
	if s < 0.15 and v < 0.2 then
		return Palette.Ink
	end
	local deg = h * 360
	if s > 0.3 and deg >= 70 and deg < 175 then
		return Palette.Wheat
	end
	return c
end

local function kp(t: number, g: number): ColorSequenceKeypoint
	return ColorSequenceKeypoint.new(t, Color3.new(g, g, g))
end

local LIP = ColorSequence.new({ kp(0, 1), kp(0.6, 0.95), kp(0.8, 0.88), kp(0.81, 0.68), kp(1, 0.6) })

local function planks(n: number): ColorSequence
	local points = { kp(0, 1) }
	for i = 1, n - 1 do
		local e = i / n
		table.insert(points, kp(e - 0.012, 0.84))
		table.insert(points, kp(e - 0.011, 0.58))
		table.insert(points, kp(e - 0.002, 0.58))
		table.insert(points, kp(e, 1))
	end
	table.insert(points, kp(1, 0.84))
	return ColorSequence.new(points)
end

local function foreign(obj: Instance, class: string): boolean
	for _, c in ipairs(obj:GetChildren()) do
		if c:IsA(class) and c.Name:sub(1, 4) ~= "Farm" then
			return true
		end
	end
	return false
end

local function clearOurs(obj: Instance)
	for _, c in ipairs(obj:GetChildren()) do
		if c.Name == "FarmCorner" or c.Name == "FarmStroke" or c.Name == "FarmGrad" or c.Name == "FarmNail" then
			c:Destroy()
		end
	end
end

local function nail(parent: Instance, ax: number, ay: number, size: number, inset: number)
	local n = Instance.new("Frame")
	n.Name = "FarmNail"
	n.AnchorPoint = Vector2.new(ax, ay)
	n.Position = UDim2.new(ax, if ax == 0 then inset else -inset, ay, if ay == 0 then inset else -inset)
	n.Size = UDim2.fromOffset(size, size)
	n.BackgroundColor3 = Palette.Nail
	n.BorderSizePixel = 0
	n.ZIndex = 40
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = n
	local s = Instance.new("UIStroke")
	s.Color = Palette.Ink
	s.Thickness = math.max(1, size * 0.18)
	s.Parent = n
	n.Parent = parent
end

local function setBg(obj: GuiObject, color: Color3)
	lastBg[obj] = color
	obj.BackgroundColor3 = color
	local info = state[obj]
	if info then
		info.color = color
		const stroke = info.stroke
		if stroke and not info.glow then
			stroke.Color = darken(color, 0.6)
		end
	end
end

local function decorate(obj: GuiObject)
	local info = state[obj]
	if not info then
		return
	end

	local abs = obj.AbsoluteSize
	local view = viewport()
	if view.X < 50 or abs.X < 1 then
		return
	end
	local full = abs.X >= view.X * 0.9 and abs.Y >= view.Y * 0.9
	local bar = not full and abs.X >= view.X * 0.9
	local s = scale()
	local big = math.min(abs.X, abs.Y) > 150 * s
	local plankCount = math.clamp(math.round(abs.Y / (70 * s)), 2, 5)
	local key = `{full}{bar}{big}{plankCount}`
	if info.key == key then
		return
	end
	info.key = key
	clearOurs(obj)
	info.stroke = nil

	if full then
		obj.BackgroundTransparency = info.origTransparency
		setBg(obj, Palette.Soil)
		return
	end

	setBg(obj, info.base)
	if info.kind == "panel" then
		obj.BackgroundTransparency = math.min(info.origTransparency, 0.08)
	end

	if not bar and not foreign(obj, "UICorner") then
		local c = Instance.new("UICorner")
		c.Name = "FarmCorner"
		c.CornerRadius = UDim.new(if big then 0.05 else 0.2, 0)
		c.Parent = obj
	end

	if not foreign(obj, "UIStroke") then
		local st = Instance.new("UIStroke")
		st.Name = "FarmStroke"
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Thickness = math.max(1.5, (if big then 4 else 3) * s)
		st.Color = if info.glow then Palette.Wheat else darken(info.color, 0.6)
		st.Parent = obj
		info.stroke = st
		if info.glow then
			TweenService:Create(
				st,
				TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Thickness = st.Thickness * 2.2 }
			):Play()
		end
	end

	local isImage = (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) and (obj :: any).Image ~= ""
	if not isImage and not foreign(obj, "UIGradient") then
		local g = Instance.new("UIGradient")
		g.Name = "FarmGrad"
		g.Rotation = 90
		g.Color = if info.kind == "panel" and not bar and big then planks(plankCount) else LIP
		g.Parent = obj
	end

	local outer = true
	local p = obj.Parent
	while p and p:IsA("GuiObject") do
		if p:FindFirstChild("FarmNail") then
			outer = false
			break
		end
		p = p.Parent
	end
	if info.kind == "panel" and big and not bar and outer then
		local size = math.clamp(10 * s, 5, 14)
		local inset = 8 * s
		nail(obj, 0, 0, size, inset)
		nail(obj, 1, 0, size, inset)
		nail(obj, 0, 1, size, inset)
		nail(obj, 1, 1, size, inset)
	end
end

local function applyBg(obj: GuiObject)
	if obj.BackgroundTransparency >= 0.99 then
		return
	end
	local color, kind = remapBg(obj.BackgroundColor3)
	if obj.Name == "Header" then
		color, kind = Palette.Barn, "color"
		obj.Rotation = -2
	end

	local info = state[obj]
	if not info then
		local parent = obj.Parent
		info = {
			origTransparency = obj.BackgroundTransparency,
			kind = kind,
			color = color,
			base = color,
			glow = obj:IsA("GuiButton") and parent ~= nil and parent.Name == "Play",
			key = nil,
			stroke = nil,
		} :: SkinState
		state[obj] = info
	end
	info.kind = kind
	info.base = color
	const key = info.key
	if key and key:sub(1, 4) == "true" then
		setBg(obj, Palette.Soil)
	else
		setBg(obj, color)
	end
	decorate(obj)
end

local function applyText(obj: TextLabel | TextButton | TextBox)
	if obj.FontFace.Family ~= Palette.Font.Family then
		obj.FontFace = Font.new(Palette.Font.Family, obj.FontFace.Weight, obj.FontFace.Style)
	end
	local c = remapText(obj.TextColor3)
	if not same(c, obj.TextColor3) then
		lastText[obj] = c
		obj.TextColor3 = c
	end

	if obj:GetAttribute("FarmText") then
		return
	end
	obj:SetAttribute("FarmText", true)

	if obj.BackgroundTransparency < 0.99 then
		obj.TextStrokeColor3 = Palette.Ink
		obj.TextStrokeTransparency = 0
	elseif not foreign(obj, "UIStroke") then
		local st = Instance.new("UIStroke")
		st.Name = "FarmTextStroke"
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Color = Palette.Ink
		st.Parent = obj
		local function fit()
			st.Thickness = math.clamp(obj.TextBounds.Y * 0.09, 1, 5)
		end
		fit()
		obj:GetPropertyChangedSignal("TextBounds"):Connect(fit)
	end
end

local function clickPosition(btn: GuiButton): Vector2
	if UserInputService.MouseEnabled then
		return UserInputService:GetMouseLocation()
	end
	local center = btn.AbsolutePosition + btn.AbsoluteSize / 2
	local gui = btn:FindFirstAncestorWhichIsA("ScreenGui")
	if gui and not gui.IgnoreGuiInset then
		center += GuiService:GetGuiInset()
	end
	return center
end

local function wireButton(btn: GuiButton)
	btn.MouseEnter:Connect(function()
		if btn.BackgroundTransparency < 0.99 then
			FarmVFX.Shine(btn)
		end
		FarmVFX.Wiggle(btn)
	end)
	btn.Activated:Connect(function()
		local color = if btn.BackgroundTransparency < 0.99 then btn.BackgroundColor3 else Palette.Leaf
		FarmVFX.Burst(clickPosition(btn), color)
	end)

	local info = state[btn]
	if info and info.glow then
		task.spawn(function()
			while btn.Parent do
				task.wait(2.6)
				if btn.Visible and btn.AbsoluteSize.X > 0 then
					FarmVFX.Shine(btn)
				end
			end
		end)
	end
end

local function process(obj: Instance)
	if not obj:IsA("GuiObject") or obj.Name:sub(1, 4) == "Farm" or hooked[obj] then
		return
	end
	hooked[obj] = true

	task.defer(function()
		if not obj.Parent then
			return
		end
		local isText = obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")
		if isText then
			applyText(obj :: any)
			obj:GetPropertyChangedSignal("TextColor3"):Connect(function()
				if not same((obj :: any).TextColor3, lastText[obj]) then
					applyText(obj :: any)
				end
			end)
		end

		applyBg(obj)
		obj:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
			if not same(obj.BackgroundColor3, lastBg[obj]) then
				applyBg(obj)
			end
		end)
		obj:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
			if not state[obj] then
				applyBg(obj)
			end
		end)
		obj:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			decorate(obj)
		end)

		if obj:IsA("GuiButton") then
			wireButton(obj)
		end

		if obj.Name == "Balance" and isText then
			obj:GetPropertyChangedSignal("Text"):Connect(function()
				FarmVFX.Pop(obj)
				FarmVFX.Sparkle(obj.AbsolutePosition + obj.AbsoluteSize / 2 + GuiService:GetGuiInset(), 10)
			end)
		end
	end)
end

local function hookGui(gui: LayerCollector)
	for _, d in ipairs(gui:GetDescendants()) do
		process(d)
	end
	gui.DescendantAdded:Connect(process)

	if POP_GUIS[gui.Name] then
		local function watch(screen: Instance)
			if not screen:IsA("GuiObject") then
				return
			end
			screen:GetPropertyChangedSignal("Visible"):Connect(function()
				if screen.Visible then
					local canvas = screen:FindFirstChild("Canvas")
					FarmVFX.PopIn(if canvas and canvas:IsA("GuiObject") then canvas else screen)
				end
			end)
		end
		for _, c in ipairs(gui:GetChildren()) do
			watch(c)
		end
		gui.ChildAdded:Connect(watch)
	end
end

function FarmSkin.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	FarmVFX.Init()

	local function consider(gui: Instance)
		if gui:IsA("LayerCollector") and MENU_GUIS[gui.Name] then
			hookGui(gui)
		end
	end
	for _, g in ipairs(playerGui:GetChildren()) do
		consider(g)
	end
	playerGui.ChildAdded:Connect(consider)

	FarmVFX.StartAmbient(function()
		local lobby = playerGui:FindFirstChild("LobbyUI")
		local container = lobby and lobby:FindFirstChild("Conteiner")
		return lobby ~= nil and (lobby :: ScreenGui).Enabled and container ~= nil and (container :: GuiObject).Visible
	end)
end

return FarmSkin
