local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)

local DeathCameraController = Modux.Controller("DeathCameraController"):Import("ArmsController")
type Self = typeof(DeathCameraController)

local TWEEN_TIME = 0.6

local THIRD_PERSON_OFFSET = Vector3.new(0, 3, 8)

local LOOK_AT_HEIGHT = 1.5

local RENDER_BIND_NAME = "DeathCameraController_Spectate"

local function getPlayerFromGameID(id: number): Player?
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("GameID") == id then
			return player
		end
	end
	return nil
end

DeathCameraController.GetSpectateCFrame = function(self: Self, shooterRoot: BasePart): CFrame
	local lookAt = shooterRoot.Position + Vector3.new(0, LOOK_AT_HEIGHT, 0)
	local camPosition = shooterRoot.CFrame:PointToWorldSpace(THIRD_PERSON_OFFSET)
	return CFrame.lookAt(camPosition, lookAt)
end

DeathCameraController.StopSpectating = function(self: Self)
	if not self._spectating then
		return
	end
	self._spectating = false

	print(`[DeathCameraController] Parando killcam`)

	RunService:UnbindFromRenderStep(RENDER_BIND_NAME)

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Custom
	if self.LocalHumanoid then
		camera.CameraSubject = self.LocalHumanoid
	end
end

DeathCameraController.StartSpectating = function(self: Self, shooter: Player)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local shooterCharacter = shooter.Character
	local shooterRoot = shooterCharacter and shooterCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not shooterRoot then
		return
	end

	print(`[DeathCameraController] Iniciando killcam -- espectando {shooter.Name}`)

	self._spectating = true
	self.ArmsController:HideRig()
	camera.CameraType = Enum.CameraType.Scriptable

	local startCFrame = camera.CFrame
	local tweenElapsed = 0

	RunService:BindToRenderStep(RENDER_BIND_NAME, Enum.RenderPriority.Camera.Value, function(deltaTime: number)
		local character = shooter.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			self:StopSpectating()
			return
		end

		local liveTarget = self:GetSpectateCFrame(root)

		if tweenElapsed < TWEEN_TIME then
			tweenElapsed += deltaTime
			local alpha = math.clamp(tweenElapsed / TWEEN_TIME, 0, 1)
			camera.CFrame = startCFrame:Lerp(liveTarget, alpha)
		else
			camera.CFrame = liveTarget
		end
	end)
end

DeathCameraController:OnInit(function(self)
	self._spectating = false :: boolean
end)

DeathCameraController:OnStart(function(self)
	self.Network.Packages.KillFeed:on(function(data)
		local localGameID = self.LocalPlayer:GetAttribute("GameID")
		if not localGameID or data.VictimID ~= localGameID then
			return
		end

		local shooter = getPlayerFromGameID(data.ShooterID)
		if not shooter or shooter == self.LocalPlayer then
			return
		end

		self:StartSpectating(shooter)
	end)

	self:Cleanup(self.LocalPlayer.CharacterAdded:Connect(function()
		self:StopSpectating()
	end))
end)

return DeathCameraController
