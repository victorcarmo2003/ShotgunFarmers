--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Maps = require(ReplicatedStorage.shared.Match.Maps)
local ScopeSettings = require(ReplicatedStorage.shared.Weapon.ScopeSettings)

type Strip = {
	Frame: Frame,
	Sky: Frame,
	Gradient: UIGradient,
	Viewport: ViewportFrame,
	Camera: Camera,
	Haze: Frame,
	WorldModel: WorldModel,
}

export type ScopeView = {
	WorldModels: { WorldModel },
	SetLighting: (lighting: Maps.ScopeLighting) -> (),
	SetBaseFov: (fov: number) -> (),
	Show: () -> (),
	Hide: () -> (),
	Render: (alpha: number, fraction: number, center: Vector2) -> (),
	Destroy: () -> (),
}

const PLANE_THICKNESS = 0.01

local function fullFrame(name: string, zIndex: number): Frame
	const frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.ZIndex = zIndex
	return frame
end

local function invisiblePart(name: string): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function newStrip(index: number, gui: SurfaceGui): Strip
	const frame = Instance.new("Frame")
	frame.Name = `Strip{index}`
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Visible = false
	frame.Parent = gui

	const sky = Instance.new("Frame")
	sky.Name = "Sky"
	sky.BackgroundColor3 = Color3.new(1, 1, 1)
	sky.BorderSizePixel = 0
	sky.ZIndex = 1
	sky.Parent = frame

	const gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Parent = sky

	const viewport = Instance.new("ViewportFrame")
	viewport.Name = "World"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.ZIndex = 2
	viewport.Parent = sky

	const worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	const viewportCamera = Instance.new("Camera")
	viewportCamera.Parent = viewport
	viewport.CurrentCamera = viewportCamera

	const haze = fullFrame("Haze", 3)
	haze.Parent = sky

	return {
		Frame = frame,
		Sky = sky,
		Gradient = gradient,
		Viewport = viewport,
		Camera = viewportCamera,
		Haze = haze,
		WorldModel = worldModel,
	}
end

local function new(playerGui: PlayerGui): ScopeView
	const plane = invisiblePart("ScopePlane")
	plane.Transparency = 1
	plane.Size = Vector3.new(1, 1, PLANE_THICKNESS)

	const gui = Instance.new("SurfaceGui")
	gui.Name = "ScopeSurface"
	gui.Face = Enum.NormalId.Back
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Adornee = plane

	const strips: { Strip } = {}
	const worldModels: { WorldModel } = {}
	for index = 1, ScopeSettings.StripCount do
		const strip = newStrip(index, gui)
		table.insert(strips, strip)
		table.insert(worldModels, strip.WorldModel)
	end

	local hazeBase = 1

	gui.Parent = playerGui

	local function setLighting(lighting: Maps.ScopeLighting)
		hazeBase = lighting.HazeTransparency
		for _, strip in strips do
			strip.Gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, lighting.SkyTop),
				ColorSequenceKeypoint.new(0.5, lighting.SkyMid),
				ColorSequenceKeypoint.new(1, lighting.SkyBottom),
			})
			strip.Haze.BackgroundColor3 = lighting.HazeColor
			strip.Haze.BackgroundTransparency = hazeBase
			strip.Viewport.LightColor = lighting.LightColor
			strip.Viewport.Ambient = lighting.Ambient
		end
	end

	local function setBaseFov(fov: number)
		for _, strip in strips do
			strip.Camera.FieldOfView = fov
		end
	end

	local function show()
		const camera = workspace.CurrentCamera
		if not camera then
			return
		end
		const direction = -Lighting:GetSunDirection()
		for _, strip in strips do
			strip.Viewport.LightDirection = direction
		end
		plane.Parent = camera
		gui.Enabled = true
	end

	local function hide()
		gui.Enabled = false
		plane.Parent = nil
		for _, strip in strips do
			strip.Frame.Visible = false
		end
	end

	local function place(strip: Strip, x: number, y: number, width: number, height: number, canvas: Vector2)
		const visible = width >= 1 and height >= 1
		strip.Frame.Visible = visible
		if not visible then
			return
		end
		strip.Frame.Position = UDim2.fromOffset(x, y)
		strip.Frame.Size = UDim2.fromOffset(width, height)
		strip.Sky.Position = UDim2.fromOffset(-x, -y)
		strip.Sky.Size = UDim2.fromOffset(canvas.X, canvas.Y)
	end

	local function render(alpha: number, fraction: number, center: Vector2)
		const camera = workspace.CurrentCamera
		if not camera or plane.Parent ~= camera then
			return
		end

		const viewportSize = camera.ViewportSize
		const canvas = Vector2.new(
			math.max(1, math.floor(viewportSize.X * ScopeSettings.ResolutionScale)),
			math.max(1, math.floor(viewportSize.Y * ScopeSettings.ResolutionScale))
		)
		if gui.CanvasSize ~= canvas then
			gui.CanvasSize = canvas
		end

		const width = canvas.X
		const height = canvas.Y
		const side = height * fraction / ScopeSettings.RingInnerRatio * ScopeSettings.HoleRatio
		const left = center.X * width - side / 2
		const top = center.Y * height - side / 2
		const l = math.clamp(math.floor(left + 0.5), 0, width)
		const r = math.clamp(math.floor(left + side + 0.5), 0, width)
		const t = math.clamp(math.floor(top + 0.5), 0, height)
		const b = math.clamp(math.floor(top + side + 0.5), 0, height)

		place(strips[1], 0, 0, l, height, canvas)
		place(strips[2], r, 0, width - r, height, canvas)
		place(strips[3], l, 0, r - l, t, canvas)
		place(strips[4], l, b, r - l, height - b, canvas)

		const cameraCFrame = camera.CFrame
		const tanHalf = math.tan(math.rad(camera.FieldOfView) / 2)
		const planeHeight = 2 * ScopeSettings.PlaneDistance * tanHalf
		const planeWidth = planeHeight * viewportSize.X / viewportSize.Y
		plane.Size = Vector3.new(planeWidth, planeHeight, PLANE_THICKNESS)
		plane.CFrame = cameraCFrame * CFrame.new(0, 0, -ScopeSettings.PlaneDistance)

		const skyTransparency = 1 - alpha
		const hazeTransparency = 1 - alpha * (1 - hazeBase)
		for _, strip in strips do
			if strip.Frame.Visible then
				strip.Sky.BackgroundTransparency = skyTransparency
				strip.Viewport.ImageTransparency = skyTransparency
				strip.Haze.BackgroundTransparency = hazeTransparency
				strip.Camera.CFrame = cameraCFrame
			end
		end
	end

	local function destroy()
		gui:Destroy()
		plane:Destroy()
	end

	return {
		WorldModels = worldModels,
		SetLighting = setLighting,
		SetBaseFov = setBaseFov,
		Show = show,
		Hide = hide,
		Render = render,
		Destroy = destroy,
	}
end

return {
	new = new,
}
