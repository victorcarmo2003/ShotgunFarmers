--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const TWEEN_TIME = 0.6

const THIRD_PERSON_OFFSET = Vector3.new(0, 3, 8)
const LOOK_AT_HEIGHT = 1.5

const RENDER_BIND_NAME = "DeathCameraController_Spectate"

const DeathCameraController = Modux.Controller("DeathCameraController", {
	Require = { "ArmsController", "MovementController" },
	Priority = 410,
})

function DeathCameraController:Setup()
	self.Spectating = false :: boolean
end

local function playerFromGameID(id: number): Player?
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("GameID") == id then
			return player
		end
	end

	return nil
end

local function characterRoot(player: Player): BasePart?
	const character = player.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

function DeathCameraController:GetSpectateCFrame(shooterRoot: BasePart): CFrame
	const lookAt = shooterRoot.Position + Vector3.new(0, LOOK_AT_HEIGHT, 0)
	const position = shooterRoot.CFrame:PointToWorldSpace(THIRD_PERSON_OFFSET)
	return CFrame.lookAt(position, lookAt)
end

function DeathCameraController:StopSpectating()
	if not self.Spectating then
		return
	end
	self.Spectating = false

	RunService:UnbindFromRenderStep(RENDER_BIND_NAME)

	const camera = workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Custom

	const humanoid = self.Dependencies.MovementController.Humanoid
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

function DeathCameraController:StartSpectating(shooter: Player)
	const camera = workspace.CurrentCamera
	if not camera or not characterRoot(shooter) then
		return
	end

	self.Spectating = true
	self.Dependencies.ArmsController:ClearRig()
	camera.CameraType = Enum.CameraType.Scriptable

	const startCFrame = camera.CFrame
	local elapsed = 0

	RunService:BindToRenderStep(RENDER_BIND_NAME, Enum.RenderPriority.Camera.Value, function(deltaTime: number)
		const root = characterRoot(shooter)
		if not root then
			self:StopSpectating()
			return
		end

		const target = self:GetSpectateCFrame(root)
		if elapsed >= TWEEN_TIME then
			camera.CFrame = target
			return
		end

		elapsed += deltaTime
		camera.CFrame = startCFrame:Lerp(target, math.clamp(elapsed / TWEEN_TIME, 0, 1))
	end)
end

DeathCameraController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.KillFeed.Kill:onClient(function(data)
		const localGameID = Players.LocalPlayer:GetAttribute("GameID")
		if localGameID == nil or data.VictimID ~= localGameID then
			return
		end

		const shooter = playerFromGameID(data.ShooterID)
		if not shooter or shooter == Players.LocalPlayer then
			return
		end

		self:StartSpectating(shooter)
	end)
end)

DeathCameraController:OnStart(function(self)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		self:StopSpectating()
	end)
end)

return DeathCameraController
