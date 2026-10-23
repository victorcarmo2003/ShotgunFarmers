--!strict
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local READY_ATTRIBUTE = "LoadingDone"
local ROLE_ATTRIBUTE = "ServerRole"
local ROUTER_ROLE = "Router"
local TIMEOUT = 25
local MIN_SECONDS = 2
local AUTO_CONTINUE = 3
local FADE_SECONDS = 0.6
local TIP_SECONDS = 6
local SPAWN_EVERY = 0.55
local MAX_CROPS = 9

local C = {
	SkyTop = Color3.fromRGB(96, 178, 255),
	SkyBottom = Color3.fromRGB(196, 232, 255),
	Leaf = Color3.fromRGB(108, 194, 74),
	LeafDark = Color3.fromRGB(70, 150, 52),
	Wheat = Color3.fromRGB(255, 210, 63),
	Barn = Color3.fromRGB(214, 73, 51),
	Pumpkin = Color3.fromRGB(255, 152, 28),
	Wood = Color3.fromRGB(150, 98, 52),
	WoodDark = Color3.fromRGB(96, 60, 34),
	Soil = Color3.fromRGB(92, 60, 36),
	Cream = Color3.fromRGB(255, 244, 214),
	Text = Color3.fromRGB(255, 251, 234),
	Ink = Color3.fromRGB(43, 26, 14),
}
local FONT = Font.fromEnum(Enum.Font.LuckiestGuy)
local BODY = Font.fromEnum(Enum.Font.FredokaOne)

local TIPS = {
	"Restock crates grow a fresh gun every 30 seconds. Watch for the glowing soil!",
	"Golden Apples heal 50 HP and appear every 20 seconds. Grab them before your enemies do!",
	"The Carrocket hits for 100 damage, but only carries 4 rockets. Make every shot count!",
	"Out of ammo? The Hoe and the Shovel never run dry.",
	"The Sniperagus deals 75 damage. Find a high spot and aim for the head!",
	"Get 2, 3 or 4 kills within 4 seconds for DOUBLE, TRIPLE and QUAD KILL medals.",
	"Free For All: first to 30 kills wins. Team Deathmatch: first team to 75!",
	"Practice mode gives you every gun with infinite ammo. Perfect for warming up.",
	"Throw a Pinapple or an Onionnade into a crowd for a big multi-kill.",
	"Got a code? Redeem it in the SHOP by pressing CODE.",
	"Press Q to go back from any menu.",
	"Invite your friends with the INVITE button and play as a squad!",
}

local CROPS = { "🥕", "🌽", "🍅", "🍆", "🥦", "🍉", "🍓", "🌶️", "🍍", "🥔" }
local GOLDEN = "⭐"

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local started = os.clock()
local connections: { RBXScriptConnection } = {}

local camera = workspace.CurrentCamera
local waitStart = os.clock()
while (not camera or camera.ViewportSize.Y < 10) and os.clock() - waitStart < 2 do
	task.wait()
	camera = workspace.CurrentCamera
end
local STROKE_SCALE = if camera then math.max(camera.ViewportSize.Y / 1080 * 1.5, 1) else 1

local function new(class: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(r: number): UICorner
	return new("UICorner", { CornerRadius = UDim.new(r, 0) })
end

local function stroke(thickness: number, color: Color3?, border: boolean?): UIStroke
	return new("UIStroke", {
		Thickness = thickness * STROKE_SCALE,
		Color = color or C.Ink,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual,
	})
end

local function gray(t: number, g: number): ColorSequenceKeypoint
	return ColorSequenceKeypoint.new(t, Color3.new(g, g, g))
end
local LIP = ColorSequence.new({ gray(0, 1), gray(0.6, 0.95), gray(0.78, 0.88), gray(0.79, 0.68), gray(1, 0.6) })

local function text(props: { [string]: any }): TextLabel
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = props.Font or FONT,
		Text = props.Text or "",
		TextColor3 = props.Color or C.Text,
		TextScaled = true,
		TextWrapped = props.Wrapped == true,
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position,
		Size = props.Size,
		ZIndex = props.ZIndex or 5,
		Name = props.Name or "Text",
		Parent = props.Parent,
	}, { stroke(props.Stroke or 2.5) })
	return label
end

local function px(): number
	local camera = workspace.CurrentCamera
	return if camera then math.max(camera.ViewportSize.Y / 1080, 0.4) else 1
end

local gui = new("ScreenGui", {
	Name = "LoadingScreen",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local root = new("Frame", {
	Name = "Root",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.Ink,
	BorderSizePixel = 0,
	Parent = gui,
})

local POSTERS = {
	"rbxassetid://90339424446992",
	"rbxassetid://83633686102846",
	"rbxassetid://96105075737080",
	"rbxassetid://70939426168058",
}
local POSTER_ASPECT = 2 / 3
local POSTER_HEIGHT = 1.25
local POSTER_ANCHOR_Y = 0.62
local POSTER_GAP = 0.03
local WALL_SPEED = 28
local wall = new("Frame", {
	Name = "Wall",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.Ink,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 0,
	Parent = root,
})
local posters: { ImageLabel } = {}
for i = 1, #POSTERS * 2 do
	local poster: ImageLabel = new("ImageLabel", {
		Name = "Poster",
		AnchorPoint = Vector2.new(0, POSTER_ANCHOR_Y),
		Size = UDim2.fromScale(1, POSTER_HEIGHT),
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Image = POSTERS[(i - 1) % #POSTERS + 1],
		ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Crop,
		Rotation = if i % 2 == 0 then 1.2 else -1.2,
		ZIndex = 0,
		Parent = wall,
	}, {
		new("UIAspectRatioConstraint", { AspectRatio = POSTER_ASPECT }),
		stroke(5, C.Ink, true),
	})
	table.insert(posters, poster)
end
task.spawn(function()
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(posters)
	end)
	for _, poster in ipairs(posters) do
		TweenService:Create(poster, TweenInfo.new(0.8), { ImageTransparency = 0 }):Play()
	end
end)

local function shade(rotation: number, near: number, far: number)
	new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = root,
	}, {
		new("UIGradient", {
			Rotation = rotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, near),
				NumberSequenceKeypoint.new(0.45, far),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
end
new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 1, Parent = root })
shade(-90, 0.05, 0.75)
shade(90, 0.15, 0.85)
shade(0, 0.45, 1)
shade(180, 0.45, 1)

local canvas = new("Frame", {
	Name = "Canvas",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 4,
	Parent = root,
}, { new("UIAspectRatioConstraint", { AspectRatio = 16 / 9 }) })

local field = new("Frame", { Name = "Field", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = root })
local fx = new("Frame", { Name = "FX", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20, Parent = root })

local titleRow = new("Frame", {
	Name = "Title",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.17),
	Size = UDim2.fromScale(0.8, 0.16),
	BackgroundTransparency = 1,
	ZIndex = 8,
	Parent = canvas,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local letters: { { label: TextLabel, shadow: TextLabel, index: number } } = {}
local TITLE = "PLANT AND SHOOT"
local TITLE_COLORS = { C.Wheat, C.Leaf, C.Pumpkin, C.Barn }
local colorIndex = 0
for i = 1, #TITLE do
	local ch = TITLE:sub(i, i)
	local slot = new("Frame", {
		LayoutOrder = i,
		Size = UDim2.fromScale(if ch == " " then 0.03 else 0.07, 1),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = titleRow,
	})
	if ch ~= " " then
		colorIndex += 1
		local shadow = text({
			Text = ch,
			Position = UDim2.fromScale(0.5, 0.56),
			Size = UDim2.fromScale(1.15, 1),
			Color = C.Ink,
			Stroke = 6,
			ZIndex = 7,
			Parent = slot,
		})
		local label = text({
			Text = ch,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.15, 1),
			Color = TITLE_COLORS[(colorIndex - 1) % #TITLE_COLORS + 1],
			Stroke = 6,
			ZIndex = 8,
			Parent = slot,
		})
		table.insert(letters, { label = label, shadow = shadow, index = i })
	end
end

local sign = new("Frame", {
	Name = "TipSign",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.6),
	Size = UDim2.fromScale(0.52, 0.17),
	BackgroundColor3 = C.WoodDark,
	ZIndex = 10,
	Parent = canvas,
}, {
	corner(0.12),
	stroke(5, C.Ink, true),
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({ gray(0, 1), gray(0.48, 0.86), gray(0.49, 0.6), gray(0.51, 0.6), gray(0.52, 1), gray(1, 0.86) }),
	}),
})
for _, x in ipairs({ 0.2, 0.8 }) do
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(x, 0.95),
		Size = UDim2.fromScale(0.035, 0.75),
		BackgroundColor3 = C.Wood,
		ZIndex = 9,
		Parent = sign,
	}, { stroke(4, C.Ink, true) })
end
local tipTab = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromScale(0.22, 0.42),
	Rotation = -4,
	BackgroundColor3 = C.Barn,
	ZIndex = 12,
	Parent = sign,
}, { corner(0.25), stroke(4, C.Ink, true), new("UIGradient", { Rotation = 90, Color = LIP }) })
text({ Text = "💡 TIP", Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromScale(0.85, 0.7), ZIndex = 13, Parent = tipTab })

local tipLabel = text({
	Name = "Tip",
	Font = BODY,
	Text = "",
	Wrapped = true,
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.78, 0.62),
	ZIndex = 12,
	Parent = sign,
})
new("UITextSizeConstraint", { MaxTextSize = 34, Parent = tipLabel })
local tipScale = new("UIScale", { Parent = tipLabel })

local dots = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.9),
	Size = UDim2.fromScale(0.6, 0.08),
	BackgroundTransparency = 1,
	ZIndex = 12,
	Parent = sign,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.012, 0),
	}),
})
local dotFrames: { Frame } = {}
for i = 1, #TIPS do
	dotFrames[i] = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = C.Cream,
		BackgroundTransparency = 0.6,
		ZIndex = 12,
		Parent = dots,
	}, { corner(1) })
end

local function pressable(props: { [string]: any }): TextButton
	local button = new("TextButton", {
		Name = props.Name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.Position,
		Size = props.Size,
		BackgroundColor3 = props.Color,
		AutoButtonColor = false,
		Text = "",
		ZIndex = props.ZIndex or 12,
		Parent = props.Parent,
	}, { corner(props.Corner or 0.3), stroke(4, C.Ink, true), new("UIGradient", { Rotation = 90, Color = LIP }) })
	local scale = new("UIScale", { Parent = button })
	text({ Text = props.Text, Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.8, 0.7), ZIndex = (props.ZIndex or 12) + 1, Parent = button })
	local function to(s: number)
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = s }):Play()
	end
	button.MouseEnter:Connect(function()
		to(1.12)
	end)
	button.MouseLeave:Connect(function()
		to(1)
	end)
	button.MouseButton1Down:Connect(function()
		to(0.9)
	end)
	button.MouseButton1Up:Connect(function()
		to(1.12)
	end)
	return button
end

local prevTip = pressable({ Name = "Prev", Text = "<", Color = C.Leaf, Position = UDim2.fromScale(0.055, 0.5), Size = UDim2.fromScale(0.07, 0.45), Parent = sign })
local nextTip = pressable({ Name = "Next", Text = ">", Color = C.Leaf, Position = UDim2.fromScale(0.945, 0.5), Size = UDim2.fromScale(0.07, 0.45), Parent = sign })

local tipIndex = math.random(#TIPS)
local tipTimer = 0
local function showTip(index: number)
	tipIndex = (index - 1) % #TIPS + 1
	tipTimer = 0
	tipLabel.Text = TIPS[tipIndex]
	for i, d in ipairs(dotFrames) do
		d.BackgroundTransparency = if i == tipIndex then 0 else 0.6
		d.BackgroundColor3 = if i == tipIndex then C.Wheat else C.Cream
	end
	tipScale.Scale = 0.75
	TweenService:Create(tipScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
showTip(tipIndex)
prevTip.Activated:Connect(function()
	showTip(tipIndex - 1)
end)
nextTip.Activated:Connect(function()
	showTip(tipIndex + 1)
end)

local bar = new("Frame", {
	Name = "Progress",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.86),
	Size = UDim2.fromScale(0.5, 0.045),
	BackgroundColor3 = C.Soil,
	ZIndex = 10,
	Parent = canvas,
}, { corner(1), stroke(5, C.Ink, true) })
local fill = new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = C.Leaf,
	ZIndex = 11,
	Parent = bar,
}, { corner(1), new("UIGradient", { Rotation = 90, Color = LIP }) })
local sprout = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0, 0.3),
	Size = UDim2.fromScale(0.06, 2.4),
	BackgroundTransparency = 1,
	ZIndex = 12,
	Parent = bar,
})
local sproutScale = new("UIScale", { Scale = 0.4, Parent = sprout })
new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.16, 0.75), BackgroundColor3 = C.LeafDark, ZIndex = 12, Parent = sprout }, { corner(1), stroke(2) })
for _, side in ipairs({ -1, 1 }) do
	local leaf = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + side * 0.28, 0.32),
		Size = UDim2.fromScale(0.55, 0.32),
		Rotation = side * -25,
		BackgroundColor3 = C.Leaf,
		ZIndex = 13,
		Parent = sprout,
	}, { stroke(2, C.Ink, true) })
	local c = Instance.new("UICorner")
	pcall(function()
		c.TopLeftRadius = UDim.new(1, 0)
		c.BottomRightRadius = UDim.new(1, 0)
		c.TopRightRadius = UDim.new(0, 0)
		c.BottomLeftRadius = UDim.new(0, 0)
	end)
	c.Parent = leaf
end

local percentLabel = text({ Text = "0%", Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3, 0.8), ZIndex = 14, Parent = bar })
local statusLabel = text({ Name = "Status", Font = BODY, Text = "LOADING...", Position = UDim2.fromScale(0.5, 0.92), Size = UDim2.fromScale(0.5, 0.04), ZIndex = 10, Parent = canvas })

local scorePanel = new("Frame", {
	Name = "Harvest",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.fromScale(0.02, 0.03),
	Size = UDim2.fromScale(0.2, 0.08),
	BackgroundColor3 = C.WoodDark,
	ZIndex = 10,
	Parent = canvas,
}, { corner(0.3), stroke(4, C.Ink, true), new("UIGradient", { Rotation = 90, Color = LIP }) })
local scoreLabel = text({ Text = "🧺 HARVEST: 0", Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromScale(0.88, 0.62), ZIndex = 11, Parent = scorePanel })
local scorePop = new("UIScale", { Parent = scorePanel })
local hint = text({
	Name = "Hint",
	Font = BODY,
	Text = "Tap the falling crops while you wait!",
	Position = UDim2.fromScale(0.5, 0.29),
	Size = UDim2.fromScale(0.4, 0.035),
	ZIndex = 10,
	Parent = canvas,
})

type Particle = {
	frame: Frame,
	pos: Vector2,
	vel: Vector2,
	age: number,
	life: number,
	spin: number,
	g: number,
}

type Crop = {
	button: TextButton,
	x: number,
	y: number,
	fall: number,
	sway: number,
	phase: number,
	spin: number,
	golden: boolean,
	alive: boolean,
}

local particles: { Particle } = {}
local function burst(pos: Vector2, color: Color3, count: number)
	local s = px()
	for _ = 1, count do
		local size = math.random(8, 16) * s
		local p: Frame = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(pos.X, pos.Y),
			Size = UDim2.fromOffset(size, size),
			Rotation = math.random(0, 90),
			BackgroundColor3 = if math.random() < 0.5 then color else C.Wheat,
			ZIndex = 21,
			Parent = fx,
		}, { corner(if math.random() < 0.5 then 1 else 0.2), stroke(math.max(1, size * 0.12), C.Ink, true) })
		local a = math.rad(math.random(0, 360))
		local speed = math.random(200, 420) * s
		table.insert(particles, {
			frame = p,
			pos = pos,
			vel = Vector2.new(math.cos(a), math.sin(a) - 0.7) * speed,
			age = 0,
			life = 0.5 + math.random() * 0.35,
			spin = math.random(-400, 400),
			g = 1200 * s,
		})
	end
end

local function floatText(pos: Vector2, str: string, color: Color3)
	local s = px()
	local label = text({
		Text = str,
		Color = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		Size = UDim2.fromOffset(110 * s, 46 * s),
		Stroke = 3,
		ZIndex = 22,
		Parent = fx,
	})
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, { Position = UDim2.fromOffset(pos.X, pos.Y - 70 * s), TextTransparency = 1 }):Play()
	local st = label:FindFirstChildOfClass("UIStroke")
	if st then
		TweenService:Create(st, info, { Transparency = 1 }):Play()
	end
	task.delay(0.75, function()
		label:Destroy()
	end)
end

local crops: { Crop } = {}
local score = 0
local combo = 0
local lastHarvest = 0

local function bumpScore(amount: number)
	score += amount
	scoreLabel.Text = `🧺 HARVEST: {score}`
	scorePop.Scale = 1.25
	TweenService:Create(scorePop, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if hint.Parent then
		TweenService:Create(hint, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		local st = hint:FindFirstChildOfClass("UIStroke")
		if st then
			TweenService:Create(st, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end
end

local function spawnCrop()
	local s = px()
	local view = (workspace.CurrentCamera :: Camera).ViewportSize
	local golden = math.random() < 0.08
	local size = (if golden then 70 else math.random(56, 76)) * s
	local button: TextButton = new("TextButton", {
		Name = "Crop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Text = if golden then GOLDEN else CROPS[math.random(#CROPS)],
		TextScaled = true,
		FontFace = BODY,
		AutoButtonColor = false,
		ZIndex = 7,
		Parent = field,
	})
	local crop: Crop = {
		button = button,
		x = math.random() * view.X * 0.8 + view.X * 0.1,
		y = -size,
		fall = (if golden then 260 else math.random(110, 190)) * s,
		sway = math.random(10, 40) * s,
		phase = math.random() * 6,
		spin = math.random(-60, 60),
		golden = golden,
		alive = true,
	}
	if golden then
		new("UIGradient", {
			Color = ColorSequence.new(C.Wheat, Color3.fromRGB(255, 255, 255)),
			Parent = button,
		})
	end
	button.Activated:Connect(function()
		if not crop.alive then
			return
		end
		crop.alive = false
		local now = os.clock()
		combo = if now - lastHarvest < 0.9 then combo + 1 else 1
		lastHarvest = now
		local gain = (if golden then 5 else 1) * math.min(combo, 5)
		local pos = Vector2.new(crop.x, crop.y)
		burst(pos, if golden then C.Wheat else C.Leaf, if golden then 22 else 12)
		floatText(pos, if combo > 1 then `+{gain}  x{math.min(combo, 5)}` else `+{gain}`, if golden then C.Wheat else C.Text)
		bumpScore(gain)
		local sc = new("UIScale", { Parent = button })
		TweenService:Create(sc, TweenInfo.new(0.18), { Scale = 1.6 }):Play()
		TweenService:Create(button, TweenInfo.new(0.18), { TextTransparency = 1 }):Play()
		task.delay(0.2, function()
			button:Destroy()
		end)
	end)
	table.insert(crops, crop)
end

table.insert(
	connections,
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local inset = GuiService:GetGuiInset()
			burst(Vector2.new(input.Position.X, input.Position.Y + inset.Y), C.Cream, 5)
		end
	end)
)

local progress = 0
local target = 0.05
local spawnTimer = 0
local clock = 0

table.insert(
	connections,
	RunService.RenderStepped:Connect(function(dt: number)
		clock += dt
		local view = (workspace.CurrentCamera :: Camera).ViewportSize

		local wallHeight = wall.AbsoluteSize.Y * POSTER_HEIGHT
		local step = wallHeight * POSTER_ASPECT + wallHeight * POSTER_GAP
		local offset = (clock * WALL_SPEED * (wall.AbsoluteSize.Y / 1080)) % (step * #POSTERS)
		for i, poster in ipairs(posters) do
			poster.Position = UDim2.new(0, (i - 1) * step - offset, 0.5, 0)
		end

		for _, l in ipairs(letters) do
			local wave = math.sin(clock * 3 + l.index * 0.55)
			l.label.Position = UDim2.fromScale(0.5, 0.5 + wave * 0.08)
			l.label.Rotation = wave * 5
			l.shadow.Position = UDim2.fromScale(0.5, 0.57 + wave * 0.08)
			l.shadow.Rotation = wave * 5
		end

		progress += (target - progress) * math.min(dt * 3, 1)
		fill.Size = UDim2.fromScale(math.max(progress, 0.04), 1)
		sprout.Position = UDim2.fromScale(math.max(progress, 0.04), 0.3)
		sproutScale.Scale = 0.4 + progress * 0.8
		percentLabel.Text = `{math.floor(progress * 100 + 0.5)}%`

		tipTimer += dt
		if tipTimer >= TIP_SECONDS then
			showTip(tipIndex + 1)
		end

		spawnTimer += dt
		if spawnTimer >= SPAWN_EVERY and #crops < MAX_CROPS then
			spawnTimer = 0
			spawnCrop()
		end
		for i = #crops, 1, -1 do
			local crop = crops[i]
			if crop.alive then
				crop.y += crop.fall * dt
				local x = crop.x + math.sin(clock * 2 + crop.phase) * crop.sway
				crop.button.Position = UDim2.fromOffset(x, crop.y)
				crop.button.Rotation += crop.spin * dt
				if crop.y > view.Y + 80 then
					crop.alive = false
					crop.button:Destroy()
				end
			end
			if not crop.alive then
				table.remove(crops, i)
			end
		end

		for i = #particles, 1, -1 do
			local p = particles[i]
			p.age += dt
			local t = p.age / p.life
			if t >= 1 then
				p.frame:Destroy()
				table.remove(particles, i)
			else
				p.vel += Vector2.new(0, p.g * dt)
				p.pos += p.vel * dt
				p.frame.Position = UDim2.fromOffset(p.pos.X, p.pos.Y)
				p.frame.Rotation += p.spin * dt
				p.frame.BackgroundTransparency = math.max(0, (t - 0.5) * 2)
			end
		end
	end)
)

gui.Parent = playerGui

local function setStatus(str: string)
	statusLabel.Text = str
end

if not game:IsLoaded() then
	setStatus("LOADING THE FARM...")
	task.spawn(function()
		while not game:IsLoaded() do
			target = math.min(target + 0.02, 0.45)
			task.wait(0.25)
		end
	end)
	game.Loaded:Wait()
end
target = math.max(target, 0.5)

setStatus("PLANTING THE SEEDS...")
while player:GetAttribute(READY_ATTRIBUTE) ~= true and os.clock() - started < TIMEOUT do
	if workspace:GetAttribute(ROLE_ATTRIBUTE) == ROUTER_ROLE then
		setStatus("CONNECTING TO LOBBY...")
		target = 0.95
		pcall(function()
			TeleportService:SetTeleportGui(gui)
		end)
		while true do
			task.wait(1)
		end
	end
	target = math.min(target + 0.01, 0.92)
	task.wait(0.1)
end

local remaining = MIN_SECONDS - (os.clock() - started)
if remaining > 0 then
	task.wait(remaining)
end

target = 1
setStatus("READY!")
task.wait(0.4)

local continued = false
local playButton = pressable({
	Name = "Play",
	Text = "PLAY!",
	Color = C.Leaf,
	Position = UDim2.fromScale(0.5, 0.78),
	Size = UDim2.fromScale(0.16, 0.085),
	ZIndex = 15,
	Parent = canvas,
})
local playPop = playButton:FindFirstChildOfClass("UIScale")
if playPop then
	playPop.Scale = 0
	TweenService:Create(playPop, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
local glow = playButton:FindFirstChildOfClass("UIStroke")
if glow then
	glow.Color = C.Wheat
	TweenService:Create(glow, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 9 }):Play()
end
playButton.Activated:Connect(function()
	continued = true
end)

local readyAt = os.clock()
while not continued and os.clock() - readyAt < AUTO_CONTINUE do
	setStatus(`READY! STARTING IN {math.ceil(AUTO_CONTINUE - (os.clock() - readyAt))}...`)
	task.wait(0.1)
end

local center = playButton.AbsolutePosition + playButton.AbsoluteSize / 2
burst(center, C.Leaf, 26)
TweenService:Create(root, TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = UDim2.fromScale(0, -1.15) }):Play()
task.wait(FADE_SECONDS)

for _, connection in ipairs(connections) do
	connection:Disconnect()
end
gui:Destroy()
