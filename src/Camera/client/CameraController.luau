--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const MAX_RANGE = 150
const FIRST_PERSON_ZOOM = 0.5
const LOOK_AT_DISTANCE = 20

const RENDER_BIND_NAME = "CameraController_Shake"

const RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1

const SHAKE_DECAY = 2.5
const SHAKE_FREQUENCY = 12
const SHAKE_POSITION_AMPLITUDE = 0.15
const SHAKE_ROTATION_AMPLITUDE = 4

const TILT_MAX_ANGLE = 1
const TILT_SMOOTH_RATE = 8

const raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

export type EffectState = { Trauma: number, Seed: number }

type EffectHandler = {
	Init: () -> EffectState,
	Trigger: (state: EffectState, intensity: number) -> (),
	Update: (state: EffectState, deltaTime: number) -> CFrame,
}

const EFFECT_HANDLERS: { [string]: EffectHandler } = {
	Shake = {
		Init = function(): EffectState
			return { Trauma = 0, Seed = math.random() * 1000 }
		end,
		Trigger = function(state: EffectState, intensity: number)
			state.Trauma = math.clamp(state.Trauma + intensity, 0, 1)
		end,
		Update = function(state: EffectState, deltaTime: number): CFrame
			state.Trauma = math.max(0, state.Trauma - SHAKE_DECAY * deltaTime)
			if state.Trauma <= 0 then
				return CFrame.identity
			end

			const shake = state.Trauma ^ 2
			const time = os.clock() * SHAKE_FREQUENCY
			const offsetX = math.noise(state.Seed, time) * SHAKE_POSITION_AMPLITUDE * shake
			const offsetY = math.noise(state.Seed + 100, time) * SHAKE_POSITION_AMPLITUDE * shake
			const rotZ = math.noise(state.Seed + 200, time) * SHAKE_ROTATION_AMPLITUDE * shake

			return CFrame.new(offsetX, offsetY, 0) * CFrame.Angles(0, 0, math.rad(rotZ))
		end,
	},
}

const CameraController = Modux.Controller("CameraController", {
	Require = { "GameStateController", "MovementController" },
	Priority = 430,
})

function CameraController:Setup()
	self.Effects = {} :: { [string]: EffectState }
	self.CurrentTilt = 0 :: number
	self.FirstPerson = false :: boolean
end

local function playerFromPart(part: Instance): Player?
	const model = part.Parent
	if not model or not model:IsA("Model") then
		return nil
	end

	return Players:GetPlayerFromCharacter(model)
end

local function lookRay(): Ray?
	const camera = workspace.CurrentCamera
	if not camera then
		return nil
	end

	const location = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(location.X, location.Y, 0)
end

function CameraController:GetLookPart(): (BasePart?, Player?)
	const ray = lookRay()
	if not ray then
		return nil, nil
	end

	const character = self.Dependencies.MovementController.Character
	const filter: { Instance } = if character then { character } else {}
	raycastParams.FilterDescendantsInstances = filter

	const result = workspace:Raycast(ray.Origin, ray.Direction * MAX_RANGE, raycastParams)
	if not result then
		return nil, nil
	end

	return result.Instance, playerFromPart(result.Instance)
end

function CameraController:GetLookAt(): Vector3?
	const ray = lookRay()
	return if ray then ray.Origin + ray.Direction * LOOK_AT_DISTANCE else nil
end

function CameraController:GetLookDirection(): Vector3?
	const ray = lookRay()
	if not ray or ray.Direction.Magnitude < 1e-4 then
		return nil
	end

	return ray.Direction.Unit
end

function CameraController:CreateEffect(effectName: string, intensity: number)
	const handler = EFFECT_HANDLERS[effectName]
	if not handler then
		warn(`[CameraController] efeito "{effectName}" nao existe`)
		return
	end

	local state = self.Effects[effectName]
	if not state then
		state = handler.Init()
		self.Effects[effectName] = state
	end

	handler.Trigger(state, intensity)
end

function CameraController:GetTiltOffset(camera: Camera, deltaTime: number): CFrame
	const moveDirection = self.Dependencies.MovementController:GetMoveDirection()
	local lateral = 0
	if moveDirection.Magnitude > 0 then
		lateral = camera.CFrame.RightVector:Dot(-moveDirection)
	end

	const targetTilt = -lateral * TILT_MAX_ANGLE
	const alpha = 1 - math.exp(-TILT_SMOOTH_RATE * deltaTime)
	self.CurrentTilt += (targetTilt - self.CurrentTilt) * alpha

	return CFrame.Angles(0, 0, math.rad(self.CurrentTilt))
end

function CameraController:Step(deltaTime: number)
	if not self.FirstPerson then
		return
	end

	const camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local offset = self:GetTiltOffset(camera, deltaTime)
	for effectName, state in self.Effects do
		offset *= EFFECT_HANDLERS[effectName].Update(state, deltaTime)
	end

	camera.CFrame *= offset
end

CameraController:OnInit(function(self)
	self:Setup()
end)

CameraController:OnStart(function(self)
	self.Dependencies.GameStateController:Watch("FirstPerson", function(on: boolean)
		self.FirstPerson = on
		const player = Players.LocalPlayer
		player.CameraMode = if on then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic
		if on then
			player.CameraMaxZoomDistance = FIRST_PERSON_ZOOM
			player.CameraMinZoomDistance = FIRST_PERSON_ZOOM
		else
			player.CameraMaxZoomDistance = StarterPlayer.CameraMaxZoomDistance
			player.CameraMinZoomDistance = StarterPlayer.CameraMinZoomDistance
		end
	end)

	self.Dependencies.MovementController.Landed:Connect(function(intensity: number)
		self:CreateEffect("Shake", intensity)
	end)

	RunService:BindToRenderStep(RENDER_BIND_NAME, RENDER_PRIORITY, function(deltaTime: number)
		self:Step(deltaTime)
	end)
end)

return CameraController
