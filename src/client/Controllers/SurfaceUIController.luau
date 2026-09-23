local RunService = game:GetService("RunService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)

local SurfaceUIController = Modux.Controller("SurfaceUIController")
type Self = typeof(SurfaceUIController)

export type PanelConfig = {
	Depth: number?,
	Rotation: Vector3?,
}

local RENDER_BIND_NAME = "SurfaceUIController_UpdatePanels"
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1
local REFERENCE_DEPTH = 3

local SHAKE_DECAY = 2.5
local SHAKE_FREQUENCY = 12
local SHAKE_POSITION_AMPLITUDE = 0.15
local SHAKE_ROTATION_AMPLITUDE = 4

type EffectState = { Trauma: number, Seed: number }

local EFFECT_HANDLERS: {
	[string]: {
		Init: () -> EffectState,
		Trigger: (state: EffectState, intensity: number) -> (),
		Update: (state: EffectState, deltaTime: number) -> CFrame,
	},
} =
	{
		Shake = {
			Init = function()
				return { Trauma = 0, Seed = math.random() * 1000 }
			end,
			Trigger = function(state, intensity)
				state.Trauma = math.clamp(state.Trauma + intensity, 0, 1)
			end,
			Update = function(state, deltaTime)
				state.Trauma = math.max(0, state.Trauma - SHAKE_DECAY * deltaTime)
				if state.Trauma <= 0 then
					return CFrame.identity
				end

				local shake = state.Trauma ^ 2
				local time = os.clock() * SHAKE_FREQUENCY
				local offsetX = math.noise(state.Seed, time) * SHAKE_POSITION_AMPLITUDE * shake
				local offsetY = math.noise(state.Seed + 100, time) * SHAKE_POSITION_AMPLITUDE * shake
				local rotZ = math.noise(state.Seed + 200, time) * SHAKE_ROTATION_AMPLITUDE * shake

				return CFrame.new(offsetX, offsetY, 0) * CFrame.Angles(0, 0, math.rad(rotZ))
			end,
		},
	}

local function findPanelByPart(panels: { [string]: any }, part: Part): boolean
	for _, panel in panels do
		if panel.Part == part then
			return true
		end
	end
	return false
end

local function resolveSize(): Vector2
	local camera = workspace.CurrentCamera
	local aspectRatio = camera.ViewportSize.X / camera.ViewportSize.Y
	local height = 2 * REFERENCE_DEPTH * math.tan(math.rad(camera.FieldOfView) / 2)
	return Vector2.new(height * aspectRatio, height)
end

local function applySize(part: Part, size: Vector2)
	part.Size = Vector3.new(size.X, size.Y, 0.05)
end

local function buildOffset(config: PanelConfig): CFrame
	local rotation = config.Rotation or Vector3.zero
	local depth = config.Depth or REFERENCE_DEPTH
	return CFrame.new(0, 0, -depth) * CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
end

SurfaceUIController.New = function(self: Self, name: string, config: PanelConfig?): Part
	assert(not self.Panels[name], `[SurfaceUIController] Panel "{name}" já existe.`)
	local resolvedConfig: PanelConfig = config or {}

	local part = Instance.new("Part")
	part.Name = name
	applySize(part, resolveSize())
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = workspace.CurrentCamera

	self.Panels[name] = {
		Part = part,
		Offset = buildOffset(resolvedConfig),
	}

	self:Cleanup(part)

	return part
end

SurfaceUIController.Get = function(self: Self, name: string): Part?
	local panel = self.Panels[name]
	return panel and panel.Part
end

SurfaceUIController.Remove = function(self: Self, name: string)
	local panel = self.Panels[name]
	if not panel then
		return
	end
	self.Effects[panel.Part] = nil
	panel.Part:Destroy()
	self.Panels[name] = nil
end

SurfaceUIController.CreateEffect = function(self: Self, part: Part, effectName: string, intensity: number)
	local handler = EFFECT_HANDLERS[effectName]
	assert(handler, `[SurfaceUIController] Efeito "{effectName}" não existe.`)
	assert(
		findPanelByPart(self.Panels, part),
		`[SurfaceUIController] A Part informada não pertence a nenhum painel registrado.`
	)

	local partEffects = self.Effects[part]
	if not partEffects then
		partEffects = {}
		self.Effects[part] = partEffects
	end

	local state = partEffects[effectName]
	if not state then
		state = handler.Init()
		partEffects[effectName] = state
	end

	handler.Trigger(state, intensity)
end

SurfaceUIController:OnInit(function(self)
	self.Panels = {}
	self.Effects = {} :: { [Part]: { [string]: EffectState } }
end)

SurfaceUIController:OnStart(function(self)
	local lastViewportSize: Vector2? = nil

	RunService:BindToRenderStep(RENDER_BIND_NAME, RENDER_PRIORITY, function(deltaTime: number)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		if camera.ViewportSize ~= lastViewportSize then
			lastViewportSize = camera.ViewportSize
			local size = resolveSize()
			for _, panel in self.Panels do
				applySize(panel.Part, size)
			end
		end

		local cameraCFrame = camera:GetRenderCFrame()
		for _, panel in self.Panels do
			local shakeOffset = CFrame.identity
			local partEffects = self.Effects[panel.Part]
			if partEffects then
				for effectName, state in partEffects do
					shakeOffset = shakeOffset * EFFECT_HANDLERS[effectName].Update(state, deltaTime)
				end
			end
			panel.Part.CFrame = cameraCFrame * panel.Offset * shakeOffset
		end
	end)

	self:Cleanup(function()
		RunService:UnbindFromRenderStep(RENDER_BIND_NAME)
	end)
end)

return SurfaceUIController
