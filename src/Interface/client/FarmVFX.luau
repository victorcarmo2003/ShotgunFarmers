--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Palette = require(script.Parent.FarmPalette)

local FarmVFX = {}

local player = Players.LocalPlayer
local fxGui: ScreenGui? = nil
local ambientGui: ScreenGui? = nil

type Particle = {
	frame: Frame,
	pos: Vector2,
	vel: Vector2,
	gravity: number,
	drag: number,
	spin: number,
	age: number,
	life: number,
	size: number,
	aspect: number,
}

type Leaf = {
	frame: Frame,
	x: number,
	y: number,
	fall: number,
	sway: number,
	freq: number,
	phase: number,
	rot: number,
	age: number,
}

local particles: { Particle } = {}
local leaves: { Leaf } = {}

local function viewportScale(): number
	local camera = workspace.CurrentCamera
	return if camera then math.max(camera.ViewportSize.Y / 1080, 0.45) else 1
end

local function makeGui(name: string, order: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.DisplayOrder = order
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
	return c
end

local function leafCorner(parent: Instance)
	local c = Instance.new("UICorner")
	local ok = pcall(function()
		c.TopLeftRadius = UDim.new(1, 0)
		c.BottomRightRadius = UDim.new(1, 0)
		c.TopRightRadius = UDim.new(0, 0)
		c.BottomLeftRadius = UDim.new(0, 0)
	end)
	if not ok then
		c.CornerRadius = UDim.new(0.5, 0)
	end
	c.Parent = parent
end

local SHAPES = { "Seed", "Leaf", "Star" }

local function shape(kind: string, color: Color3, size: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	if kind == "Seed" then
		f.Size = UDim2.fromOffset(size * 0.75, size)
		corner(f, UDim.new(0.5, 0))
	elseif kind == "Leaf" then
		f.Size = UDim2.fromOffset(size, size)
		leafCorner(f)
	else
		f.Size = UDim2.fromOffset(size * 0.8, size * 0.8)
		f.Rotation = 45
		corner(f, UDim.new(0.2, 0))
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = Palette.Ink
	stroke.Thickness = math.max(1, size * 0.12)
	stroke.Parent = f
	return f
end

function FarmVFX.Init()
	fxGui = makeGui("FarmVFX", 1000)
	ambientGui = makeGui("FarmAmbient", -10)

	RunService.RenderStepped:Connect(function(dt: number)
		for i = #particles, 1, -1 do
			local p = particles[i]
			p.age += dt
			local t = p.age / p.life
			if t >= 1 then
				p.frame:Destroy()
				table.remove(particles, i)
			else
				p.vel += Vector2.new(0, p.gravity * dt)
				p.vel *= (1 - p.drag * dt)
				p.pos += p.vel * dt
				p.frame.Position = UDim2.fromOffset(p.pos.X, p.pos.Y)
				p.frame.Rotation += p.spin * dt
				local fade = if t > 0.55 then (t - 0.55) / 0.45 else 0
				p.frame.BackgroundTransparency = fade
				local stroke = p.frame:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Transparency = fade
				end
				local s = p.size * (1 - fade * 0.6)
				p.frame.Size = UDim2.fromOffset(s * p.aspect, s)
			end
		end

		local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
		for i = #leaves, 1, -1 do
			local l = leaves[i]
			l.age += dt
			local y = l.y + l.fall * l.age
			local x = l.x + math.sin(l.age * l.freq + l.phase) * l.sway
			l.frame.Position = UDim2.fromOffset(x, y)
			l.frame.Rotation = l.rot + math.sin(l.age * l.freq + l.phase) * 35
			if y > vp.Y + 40 then
				l.frame:Destroy()
				table.remove(leaves, i)
			end
		end
	end)
end

function FarmVFX.Burst(pos: Vector2, baseColor: Color3?)
	if not fxGui then
		return
	end
	local s = viewportScale()
	local colors = { baseColor or Palette.Leaf, Palette.Wheat, Palette.Leaf, Palette.Cream, Palette.Pumpkin }

	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(pos.X, pos.Y)
	ring.Size = UDim2.fromOffset(10 * s, 10 * s)
	ring.BackgroundTransparency = 1
	corner(ring, UDim.new(1, 0))
	local rs = Instance.new("UIStroke")
	rs.Color = Palette.Wheat
	rs.Thickness = 5 * s
	rs.Parent = ring
	ring.Parent = fxGui
	local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = UDim2.fromOffset(150 * s, 150 * s) }):Play()
	TweenService:Create(rs, info, { Transparency = 1, Thickness = 1 }):Play()
	task.delay(0.45, function()
		ring:Destroy()
	end)

	for _ = 1, 18 do
		local kind = SHAPES[math.random(#SHAPES)]
		local size = math.random(13, 22) * s
		local f = shape(kind, colors[math.random(#colors)], size)
		f.Position = UDim2.fromOffset(pos.X, pos.Y)
		f.Parent = fxGui
		local angle = math.rad(math.random(0, 360))
		local speed = math.random(220, 460) * s
		table.insert(particles, {
			frame = f,
			pos = pos,
			vel = Vector2.new(math.cos(angle), math.sin(angle) - 0.6) * speed,
			gravity = 1300 * s,
			drag = 2.2,
			spin = math.random(-540, 540),
			age = 0,
			life = 0.55 + math.random() * 0.35,
			size = size,
			aspect = if kind == "Seed" then 0.75 else 1,
		})
	end
end

function FarmVFX.Sparkle(pos: Vector2, count: number?)
	if not fxGui then
		return
	end
	local s = viewportScale()
	for _ = 1, count or 8 do
		local size = math.random(10, 16) * s
		local f = shape("Star", Palette.Wheat, size)
		f.Position = UDim2.fromOffset(pos.X, pos.Y)
		f.Parent = fxGui
		table.insert(particles, {
			frame = f,
			pos = pos + Vector2.new(math.random(-30, 30) * s, math.random(-8, 8) * s),
			vel = Vector2.new(math.random(-60, 60) * s, -math.random(140, 260) * s),
			gravity = 250 * s,
			drag = 1.5,
			spin = math.random(-200, 200),
			age = 0,
			life = 0.7 + math.random() * 0.4,
			size = size,
			aspect = 1,
		})
	end
end

local shining: { [GuiObject]: boolean } = setmetatable({}, { __mode = "k" }) :: any

function FarmVFX.Shine(target: GuiObject)
	if shining[target] then
		return
	end
	shining[target] = true

	local shine = Instance.new("Frame")
	shine.Name = "FarmShine"
	shine.Size = UDim2.fromScale(1, 1)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BorderSizePixel = 0
	shine.ZIndex = 50
	local existing = target:FindFirstChildOfClass("UICorner")
	if existing then
		existing:Clone().Parent = shine
	end
	local g = Instance.new("UIGradient")
	g.Rotation = 20
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Offset = Vector2.new(-1, 0)
	g.Parent = shine
	shine.Parent = target

	local tween = TweenService:Create(g, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Offset = Vector2.new(1, 0) })
	tween.Completed:Connect(function()
		shine:Destroy()
		shining[target] = nil
	end)
	tween:Play()
end

function FarmVFX.Wiggle(target: GuiObject)
	local info = TweenInfo.new(0.07, Enum.EasingStyle.Sine)
	local a = TweenService:Create(target, info, { Rotation = -3 })
	local b = TweenService:Create(target, info, { Rotation = 2.5 })
	local c = TweenService:Create(target, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Rotation = 0 })
	a.Completed:Connect(function()
		b:Play()
	end)
	b.Completed:Connect(function()
		c:Play()
	end)
	a:Play()
end

local function ownScale(target: GuiObject): UIScale?
	local mine = target:FindFirstChild("FarmPop")
	if mine then
		return mine :: UIScale
	end
	if target:FindFirstChildOfClass("UIScale") then
		return nil
	end
	local sc = Instance.new("UIScale")
	sc.Name = "FarmPop"
	sc.Parent = target
	return sc
end

function FarmVFX.PopIn(target: GuiObject)
	local sc = ownScale(target)
	if not sc then
		return
	end
	sc.Scale = 0.82
	TweenService:Create(sc, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function FarmVFX.Pop(target: GuiObject)
	local sc = ownScale(target)
	if not sc then
		return
	end
	sc.Scale = 1.35
	TweenService:Create(sc, TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function FarmVFX.StartAmbient(active: () -> boolean)
	local colors = { Palette.Leaf, Palette.LeafLight, Palette.Wheat, Palette.Blossom }
	task.spawn(function()
		while true do
			task.wait(0.32)
			const camera = workspace.CurrentCamera
			if ambientGui and camera and active() and #leaves < 28 then
				local s = viewportScale()
				local vp = camera.ViewportSize
				local size = math.random(12, 24) * s
				local f = Instance.new("Frame")
				f.AnchorPoint = Vector2.new(0.5, 0.5)
				f.BorderSizePixel = 0
				f.Size = UDim2.fromOffset(size, size)
				f.BackgroundColor3 = colors[math.random(#colors)]
				f.BackgroundTransparency = 0.15
				leafCorner(f)
				f.Parent = ambientGui
				table.insert(leaves, {
					frame = f,
					x = math.random() * vp.X,
					y = -30,
					fall = math.random(45, 95) * s,
					sway = math.random(20, 60) * s,
					freq = 0.8 + math.random() * 1.2,
					phase = math.random() * 6,
					rot = math.random(0, 360),
					age = 0,
				})
			end
			const gui = ambientGui
			if gui then
				gui.Enabled = active()
			end
		end
	end)
end

return FarmVFX
