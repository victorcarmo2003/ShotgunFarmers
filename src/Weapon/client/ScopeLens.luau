--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Maps = require(ReplicatedStorage.shared.Match.Maps)
local ScopeSettings = require(ReplicatedStorage.shared.Weapon.ScopeSettings)

export type Apparent = {
	Center: Vector2,
	Radius: number,
}

export type ScopeLens = {
	WorldModel: WorldModel,
	SetLighting: (lighting: Maps.ScopeLighting) -> (),
	SetFov: (fov: number) -> (),
	Attach: (lens: BasePart, anchor: Attachment?) -> boolean,
	Detach: () -> (),
	IsAttached: () -> boolean,
	Apparent: () -> Apparent?,
	SetKick: (offset: Vector2, roll: number) -> (),
	Render: (visibility: number) -> (),
	Destroy: () -> (),
}

const AXES: { Vector3 } = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }

local function component(size: Vector3, axis: number): number
	if axis == 1 then
		return size.X
	elseif axis == 2 then
		return size.Y
	end
	return size.Z
end

local function longestAxis(size: Vector3): number
	if size.X >= size.Y and size.X >= size.Z then
		return 1
	elseif size.Y >= size.Z then
		return 2
	end
	return 3
end

local function fullFrame(name: string, zIndex: number): Frame
	const frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.ZIndex = zIndex
	return frame
end

local function centered(name: string, zIndex: number, size: UDim2): Frame
	const frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = size
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BorderSizePixel = 0
	frame.ZIndex = zIndex
	return frame
end

local function offsetFor(lens: BasePart, camera: Camera, axis: number, sign: number, anchor: Vector3?, extra: number?): CFrame
	const normal = AXES[axis] * sign
	const half = component(lens.Size, axis) / 2

	local up = AXES[1]
	local bestDot = -math.huge
	for index = 1, 3 do
		if index == axis then
			continue
		end
		for _, direction in { 1, -1 } do
			const candidate = AXES[index] * direction
			const dot = lens.CFrame:VectorToWorldSpace(candidate):Dot(camera.CFrame.UpVector)
			if dot > bestDot then
				bestDot = dot
				up = candidate
			end
		end
	end

	const back = -normal
	const right = up:Cross(back)
	if anchor then
		return CFrame.fromMatrix(
			anchor + normal * ((extra or 0) + ScopeSettings.LensGap + ScopeSettings.LensThickness / 2),
			right,
			up,
			back
		)
	end
	const distance = half + ScopeSettings.LensGap + ScopeSettings.LensThickness / 2
	return CFrame.fromMatrix(normal * distance, right, up, back)
end

local function new(playerGui: PlayerGui): ScopeLens
	const gui = Instance.new("SurfaceGui")
	gui.Name = "ScopeLensSurfaceGui"
	gui.Face = Enum.NormalId.Front
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(ScopeSettings.LensResolution, ScopeSettings.LensResolution)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.Enabled = false

	const lensFrame = Instance.new("Frame")
	lensFrame.Name = "Lens"
	lensFrame.Size = UDim2.fromScale(1, 1)
	lensFrame.BackgroundTransparency = 1
	lensFrame.BorderSizePixel = 0
	lensFrame.ClipsDescendants = true
	lensFrame.ZIndex = 1
	lensFrame.Parent = gui

	const corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = lensFrame

	const sky = fullFrame("Sky", 1)
	sky.BackgroundColor3 = Color3.new(1, 1, 1)
	sky.Parent = lensFrame

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

	const haze = fullFrame("Haze", 5)
	haze.Parent = lensFrame

	const ringScale = ScopeSettings.LensCircleFraction / ScopeSettings.RingInnerRatio
	const ring = Instance.new("ImageLabel")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(ringScale, ringScale)
	ring.BackgroundTransparency = 1
	ring.BorderSizePixel = 0
	ring.Image = ScopeSettings.RingImage
	ring.ScaleType = Enum.ScaleType.Stretch
	ring.ZIndex = 10
	ring.Parent = gui

	const horizontal = centered(
		"Horizontal",
		11,
		UDim2.new(ScopeSettings.LensCircleFraction, 0, 0, ScopeSettings.LensReticleThickness)
	)
	horizontal.Parent = gui
	const vertical = centered(
		"Vertical",
		11,
		UDim2.new(0, ScopeSettings.LensReticleThickness, ScopeSettings.LensCircleFraction, 0)
	)
	vertical.Parent = gui
	const dot = centered("Dot", 12, UDim2.fromOffset(ScopeSettings.LensReticleDot, ScopeSettings.LensReticleDot))
	dot.Parent = gui

	gui.Parent = playerGui

	local hazeBase = 1
	local attachedLens: BasePart? = nil
	local surface: Part? = nil
	local motor: Motor6D? = nil
	local axis = 3
	local sign = 1
	local diameter = 0
	local anchorPosition: Vector3? = nil
	local anchorOffset = 0
	local maskSlabs: { Part } = {}
	local lastVisibility = -1

	local function buildMask(part: Part)
		table.clear(maskSlabs)
		const segments = ScopeSettings.LensMaskSegments
		const half = diameter / 2
		const inner = half * ScopeSettings.LensCircleFraction
		const outer = half * ScopeSettings.LensMaskOuter
		const depth = outer - inner
		const tangential = 2 * outer * math.tan(math.pi / segments) * ScopeSettings.LensMaskOverlap
		for index = 1, segments do
			const slab = Instance.new("Part")
			slab.Name = "ScopeLensMask"
			slab.Material = Enum.Material.Glass
			slab.Transparency = ScopeSettings.LensMaskTransparency
			slab.Color = Color3.new(1, 1, 1)
			slab.Size = Vector3.new(tangential, depth, ScopeSettings.LensThickness / 2)
			slab.Anchored = false
			slab.Massless = true
			slab.CanCollide = false
			slab.CanQuery = false
			slab.CanTouch = false
			slab.CastShadow = false

			const angle = (index - 1) / segments * math.pi * 2
			const weld = Instance.new("Motor6D")
			weld.Part0 = part
			weld.Part1 = slab
			weld.C0 = CFrame.new(0, 0, -ScopeSettings.LensMaskGap)
				* CFrame.Angles(0, 0, angle)
				* CFrame.new(0, inner + depth / 2, 0)
			weld.Parent = slab

			slab.CFrame = part.CFrame * weld.C0
			slab.Parent = part
			table.insert(maskSlabs, slab)
		end
	end

	local function setMaskVisible(visible: boolean)
		const transparency = if visible then ScopeSettings.LensMaskTransparency else 1
		for _, slab in maskSlabs do
			slab.Transparency = transparency
		end
	end

	local function setLighting(lighting: Maps.ScopeLighting)
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, lighting.SkyTop),
			ColorSequenceKeypoint.new(0.5, lighting.SkyMid),
			ColorSequenceKeypoint.new(1, lighting.SkyBottom),
		})
		hazeBase = lighting.HazeTransparency
		viewport.LightColor = lighting.LightColor
		viewport.Ambient = lighting.Ambient
		lastVisibility = -1
	end

	local function setFov(fov: number)
		viewportCamera.FieldOfView = fov
	end

	local function detach()
		gui.Enabled = false
		gui.Adornee = nil :: any
		if surface then
			surface:Destroy()
		end
		surface = nil
		motor = nil
		attachedLens = nil
		table.clear(maskSlabs)
		lastVisibility = -1
	end

	local function attach(lens: BasePart, anchor: Attachment?): boolean
		detach()

		const camera = workspace.CurrentCamera
		if not camera then
			return false
		end

		axis = longestAxis(lens.Size)
		const facing = lens.CFrame:VectorToWorldSpace(AXES[axis])
		sign = if facing:Dot(camera.CFrame.LookVector) > 0 then -1 else 1

		if anchor then
			anchorPosition = anchor.Position
			const configured = anchor:GetAttribute("LensDiameter")
			diameter = if type(configured) == "number" and configured > 0 then configured else ScopeSettings.LensDefaultDiameter
			const offset = anchor:GetAttribute("LensOffset")
			anchorOffset = if type(offset) == "number" then offset else ScopeSettings.LensDefaultOffset
		else
			anchorPosition = nil
			anchorOffset = 0
			const perpendicular: { number } = {}
			for index = 1, 3 do
				if index ~= axis then
					table.insert(perpendicular, component(lens.Size, index))
				end
			end
			diameter = (perpendicular[1] + perpendicular[2]) / 2
		end

		const part = Instance.new("Part")
		part.Name = "ScopeLensSurface"
		part.Transparency = 1
		part.Size = Vector3.new(diameter, diameter, ScopeSettings.LensThickness)
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false

		const joint = Instance.new("Motor6D")
		joint.Name = "ScopeLensMotor"
		joint.Part0 = lens
		joint.Part1 = part
		joint.C0 = offsetFor(lens, camera, axis, sign, anchorPosition, anchorOffset)
		joint.Parent = part

		part.CFrame = lens.CFrame * joint.C0
		buildMask(part)
		part.Parent = camera

		surface = part
		motor = joint
		attachedLens = lens
		viewport.LightDirection = -Lighting:GetSunDirection()
		gui.Adornee = part
		return true
	end

	local function isAttached(): boolean
		const lens = attachedLens
		return lens ~= nil and lens.Parent ~= nil
	end

	local function apparent(): Apparent?
		const camera = workspace.CurrentCamera
		const part = surface
		if not camera or not part or not part.Parent then
			return nil
		end

		const radius = diameter / 2
		const center = camera:WorldToViewportPoint(part.Position)
		const edge = camera:WorldToViewportPoint(part.Position + camera.CFrame.RightVector * radius)
		if center.Z <= 0 or edge.Z <= 0 then
			return nil
		end
		return {
			Center = Vector2.new(center.X, center.Y),
			Radius = math.abs(edge.X - center.X),
		}
	end

	local function setKick(offset: Vector2, roll: number)
		const position = UDim2.fromScale(0.5 + offset.X, 0.5 + offset.Y)
		ring.Position = position
		horizontal.Position = position
		vertical.Position = position
		dot.Position = position
		ring.Rotation = roll
		horizontal.Rotation = roll
		vertical.Rotation = roll
	end

	local function render(visibility: number)
		const camera = workspace.CurrentCamera
		const lens = attachedLens
		const joint = motor
		if not camera or not lens or not joint then
			return
		end

		if visibility <= 0 then
			if gui.Enabled then
				gui.Enabled = false
				setMaskVisible(false)
			end
			return
		end

		const facing = lens.CFrame:VectorToWorldSpace(AXES[axis] * sign)
		if facing:Dot(camera.CFrame.LookVector) > ScopeSettings.LensFlipDot then
			sign = -sign
			joint.C0 = offsetFor(lens, camera, axis, sign, anchorPosition, anchorOffset)
		end

		if not gui.Enabled then
			gui.Enabled = true
			setMaskVisible(true)
		end

		if visibility ~= lastVisibility then
			lastVisibility = visibility
			const transparency = 1 - visibility
			sky.BackgroundTransparency = transparency
			viewport.ImageTransparency = transparency
			haze.BackgroundTransparency = 1 - visibility * (1 - hazeBase)
			ring.ImageTransparency = transparency
			const reticle = 1 - visibility * (1 - ScopeSettings.LensReticleTransparency)
			horizontal.BackgroundTransparency = reticle
			vertical.BackgroundTransparency = reticle
			dot.BackgroundTransparency = reticle
		end

		viewportCamera.CFrame = camera.CFrame
	end

	local function destroy()
		detach()
		gui:Destroy()
	end

	return {
		WorldModel = worldModel,
		SetLighting = setLighting,
		SetFov = setFov,
		Attach = attach,
		Detach = detach,
		IsAttached = isAttached,
		Apparent = apparent,
		SetKick = setKick,
		Render = render,
		Destroy = destroy,
	}
end

return {
	new = new,
}
