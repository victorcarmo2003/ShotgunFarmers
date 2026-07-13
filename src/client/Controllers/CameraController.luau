local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)

local CameraController = Modux.Controller("CameraController")

const MAX_RANGE = 150
const BLACKLIST_RAYCAST = RaycastParams.new()
const BLACKLIST_OVERLAP = OverlapParams.new()

const RENDER_BIND_NAME = "CameraController_Shake"
const RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1

const SHAKE_DECAY = 2.5 -- o quanto o trauma cai por segundo
const SHAKE_FREQUENCY = 12 -- velocidade da oscilação do ruído
const SHAKE_POSITION_AMPLITUDE = 0.15 -- deslocamento máximo em studs
const SHAKE_ROTATION_AMPLITUDE = 4 -- rotação máxima em graus

const TILT_MAX_ANGLE = 1 -- graus, inclinação máxima ao se mover lateralmente
const TILT_SMOOTH_RATE = 8 -- quão rápido a inclinação persegue o alvo (maior = mais responsivo)

export type EffectState = { Trauma: number, Seed: number }

local EFFECT_HANDLERS: {
	[string]: {
		Init: () -> EffectState,
		Trigger: (state: EffectState, intensity: number) -> (),
		Update: (state: EffectState, deltaTime: number) -> CFrame,
	},
} = {
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

local function GetPlayerFromPart(part: BasePart): Player?
	local model = part.Parent
	local character: Model
	if model and model:IsA("Model") then
		character = model
	end
	local player = Players:GetPlayerFromCharacter(character)
	return player
end

CameraController.GetLookPart = function(self): (BasePart?, Player?)
	local currentCamera = workspace.CurrentCamera
	local mouse = self.LocalPlayer:GetMouse()
	local screenRay = currentCamera:ScreenPointToRay(mouse.X, mouse.Y, 0)
	if not screenRay then
		return
	end
	local worldRay = workspace:Raycast(screenRay.Origin, screenRay.Direction * MAX_RANGE, BLACKLIST_RAYCAST)
	if worldRay and worldRay.Instance then
		return worldRay.Instance, GetPlayerFromPart(worldRay.Instance)
	end
	return nil
end

CameraController.GetLookAt = function(self): Vector3?
	local currentCamera = workspace.CurrentCamera
	local mouse = self.LocalPlayer:GetMouse()
	local screenRay = currentCamera:ScreenPointToRay(mouse.X, mouse.Y, 0)
	if not screenRay then
		return
	end
	return screenRay.Origin + screenRay.Direction * 20
end

CameraController.GetLookDirection = function(self): Vector3?
	local currentCamera = workspace.CurrentCamera
	local mouse = self.LocalPlayer:GetMouse()
	local screenRay = currentCamera:ScreenPointToRay(mouse.X, mouse.Y, 0)
	if not screenRay or screenRay.Direction.Magnitude < 1e-4 then
		return
	end
	return screenRay.Direction.Unit
end

CameraController.CreateEffect = function(self, effectName: string, intensity: number)
	local handler = EFFECT_HANDLERS[effectName]
	assert(handler, `[CameraController] Efeito "{effectName}" não existe.`)

	local state = self.Effects[effectName]
	if not state then
		state = handler.Init()
		self.Effects[effectName] = state
	end

	handler.Trigger(state, intensity)
end

CameraController.GetTiltOffset = function(self, camera: Camera, deltaTime: number): CFrame
	local humanoid = self.LocalHumanoid
	if not humanoid then
		self._currentTilt = 0
		return CFrame.identity
	end

	local moveDirection = humanoid.MoveDirection
	local lateral = 0
	if moveDirection.Magnitude > 0 then
		lateral = camera.CFrame.RightVector:Dot(-moveDirection)
	end

	local targetTilt = -lateral * TILT_MAX_ANGLE
	local currentTilt = self._currentTilt or 0
	local alpha = 1 - math.exp(-TILT_SMOOTH_RATE * deltaTime)
	currentTilt += (targetTilt - currentTilt) * alpha
	self._currentTilt = currentTilt

	return CFrame.Angles(0, 0, math.rad(currentTilt))
end

CameraController.SetupFilters = function(self)
	BLACKLIST_RAYCAST.FilterType = Enum.RaycastFilterType.Exclude
	BLACKLIST_OVERLAP.FilterType = Enum.RaycastFilterType.Exclude

	local function applyLocalCharacter(character: Model)
		BLACKLIST_RAYCAST.FilterDescendantsInstances = { character }
		BLACKLIST_OVERLAP.FilterDescendantsInstances = { character }
	end

	if self.LocalCharacter then
		applyLocalCharacter(self.LocalCharacter)
	end

	self:Cleanup(self.LocalPlayer.CharacterAdded:Connect(function(character: Model)
		applyLocalCharacter(character)
	end))
end

CameraController:OnInit(function(self)
	self.Effects = {} :: { [string]: EffectState }
	self._currentTilt = 0
	self:SetupFilters()
	self.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
end)

CameraController:OnStart(function(self)
	RunService:BindToRenderStep(RENDER_BIND_NAME, RENDER_PRIORITY, function(deltaTime: number)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		local offset = self:GetTiltOffset(camera, deltaTime)
		for effectName, state in self.Effects do
			offset *= EFFECT_HANDLERS[effectName].Update(state, deltaTime)
		end

		camera.CFrame *= offset
	end)

	self:Cleanup(function()
		RunService:UnbindFromRenderStep(RENDER_BIND_NAME)
	end)
end)

return CameraController
