--!strict
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type PanelConfig = {
	Depth: number?,
	Rotation: Vector3?,
}

type EffectState = { Trauma: number, Seed: number }

type Panel = { Part: Part, Offset: CFrame }

const RENDER_BIND_NAME = "SurfaceUIController_UpdatePanels"
const RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1
const REFERENCE_DEPTH = 3

const SHAKE_DECAY = 2.5
const SHAKE_FREQUENCY = 12
const SHAKE_POSITION_AMPLITUDE = 0.15
const SHAKE_ROTATION_AMPLITUDE = 4

const TILT_RESPONSE = -2

const SurfaceUIController = Modux.Controller("SurfaceUIController", {
	Require = { "MovementController", "CameraController" },
	Priority = 820,
})

function SurfaceUIController:Setup()
	self.Panels = {} :: { [string]: Panel }
	self.Effects = {} :: { [Part]: { [string]: EffectState } }
end

local function resolveSize(): Vector2
	const camera = workspace.CurrentCamera
	if not camera then
		return Vector2.new(REFERENCE_DEPTH, REFERENCE_DEPTH)
	end

	const aspectRatio = camera.ViewportSize.X / camera.ViewportSize.Y
	const height = 2 * REFERENCE_DEPTH * math.tan(math.rad(camera.FieldOfView) / 2)
	return Vector2.new(height * aspectRatio, height)
end

local function applySize(part: Part, size: Vector2)
	part.Size = Vector3.new(size.X, size.Y, 0.05)
end

local function buildOffset(config: PanelConfig): CFrame
	const rotation = config.Rotation or Vector3.zero
	const depth = config.Depth or REFERENCE_DEPTH
	return CFrame.new(0, 0, -depth)
		* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
end

local function shakeOffsetFor(state: EffectState, deltaTime: number): CFrame
	state.Trauma = math.max(0, state.Trauma - SHAKE_DECAY * deltaTime)
	if state.Trauma <= 0 then
		return CFrame.identity
	end

	const shake = state.Trauma ^ 2
	const now = os.clock() * SHAKE_FREQUENCY
	const offsetX = math.noise(state.Seed, now) * SHAKE_POSITION_AMPLITUDE * shake
	const offsetY = math.noise(state.Seed + 100, now) * SHAKE_POSITION_AMPLITUDE * shake
	const rotZ = math.noise(state.Seed + 200, now) * SHAKE_ROTATION_AMPLITUDE * shake

	return CFrame.new(offsetX, offsetY, 0) * CFrame.Angles(0, 0, math.rad(rotZ))
end

function SurfaceUIController:New(name: string, config: PanelConfig?): Part?
	if self.Panels[name] then
		warn(`[SurfaceUIController] painel "{name}" ja existe`)
		return nil
	end

	const camera = workspace.CurrentCamera
	if not camera then
		warn(`[SurfaceUIController] sem camera para pendurar o painel "{name}"`)
		return nil
	end

	const part = Instance.new("Part")
	part.Name = name
	applySize(part, resolveSize())
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = camera

	self.Panels[name] = { Part = part, Offset = buildOffset(config or {}) }

	return part
end

function SurfaceUIController:Get(name: string): Part?
	const panel = self.Panels[name]
	return if panel then panel.Part else nil
end

function SurfaceUIController:Remove(name: string)
	const panel = self.Panels[name]
	if not panel then
		return
	end

	self.Effects[panel.Part] = nil
	panel.Part:Destroy()
	self.Panels[name] = nil
end

function SurfaceUIController:Shake(part: Part, intensity: number)
	local effects = self.Effects[part]
	if not effects then
		effects = {}
		self.Effects[part] = effects
	end

	local state = effects.Shake
	if not state then
		state = { Trauma = 0, Seed = math.random() * 1000 }
		effects.Shake = state
	end

	state.Trauma = math.clamp(state.Trauma + intensity, 0, 1)
end

function SurfaceUIController:ShakeAll(intensity: number)
	for _, panel in self.Panels do
		self:Shake(panel.Part, intensity)
	end
end

SurfaceUIController:OnInit(function(self)
	self:Setup()
end)

SurfaceUIController:OnStart(function(self)
	local lastViewportSize: Vector2? = nil

	RunService:BindToRenderStep(RENDER_BIND_NAME, RENDER_PRIORITY, function(deltaTime: number)
		const camera = workspace.CurrentCamera
		if not camera then
			return
		end

		if camera.ViewportSize ~= lastViewportSize then
			lastViewportSize = camera.ViewportSize
			const size = resolveSize()
			for _, panel in self.Panels do
				applySize(panel.Part, size)
			end
		end

		const tilt = CFrame.Angles(0, 0, math.rad(self.Dependencies.CameraController.CurrentTilt * TILT_RESPONSE))
		const cameraCFrame = camera:GetRenderCFrame() * tilt
		for _, panel in self.Panels do
			local offset = CFrame.identity
			const effects = self.Effects[panel.Part]
			if effects then
				for _, state in effects do
					offset = offset * shakeOffsetFor(state, deltaTime)
				end
			end

			panel.Part.CFrame = cameraCFrame * panel.Offset * offset
		end
	end)

	self.Dependencies.MovementController.Landed:Connect(function(intensity: number)
		self:ShakeAll(intensity)
	end)
end)

return SurfaceUIController
