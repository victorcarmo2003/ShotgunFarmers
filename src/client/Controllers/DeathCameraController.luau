local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)

-- Espectando quem te matou (3ª pessoa) enquanto o character local não respawna --
-- assume controle TOTAL da câmera (CameraType = Scriptable) nesse meio-tempo, então
-- precisa devolver o controle (Custom + CameraSubject) explicitamente ao restaurar,
-- senão a câmera fica travada pra sempre depois do respawn.
local DeathCameraController = Modux.Controller("DeathCameraController"):Import("ArmsController")

-- Tempo (segundos) da transição suave até a pose de 3ª pessoa atrás do assassino.
local TWEEN_TIME = 0.6
-- Offset (espaço local do assassino) de onde a câmera fica -- atrás e acima dele.
local THIRD_PERSON_OFFSET = Vector3.new(0, 3, 8)
-- Altura (studs) acima dos pés do assassino que a câmera mira, pra não olhar pro chão.
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

DeathCameraController.GetSpectateCFrame = function(self, shooterRoot: BasePart): CFrame
	local lookAt = shooterRoot.Position + Vector3.new(0, LOOK_AT_HEIGHT, 0)
	local camPosition = shooterRoot.CFrame:PointToWorldSpace(THIRD_PERSON_OFFSET)
	return CFrame.lookAt(camPosition, lookAt)
end

DeathCameraController.StopSpectating = function(self)
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

	-- Devolve o controle da câmera pro script default do Roblox -- CameraSubject seta
	-- de novo por segurança (o default já faz isso sozinho ao voltar pra Custom, mas
	-- não custa garantir, evita qualquer janela de câmera "perdida" logo no respawn).
	camera.CameraType = Enum.CameraType.Custom
	if self.LocalHumanoid then
		camera.CameraSubject = self.LocalHumanoid
	end
end

DeathCameraController.StartSpectating = function(self, shooter: Player)
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

	-- Sem TweenService aqui de propósito: o alvo (assassino) se move contigualmente, e um
	-- Tween normal iria mirar num CFrame estático já desatualizado no frame seguinte. Um
	-- Lerp manual no RenderStep consegue suavizar a ENTRADA (tweenElapsed < TWEEN_TIME) e
	-- continuar seguindo o alvo se movendo depois, sem descontinuidade entre as duas fases.
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

	-- CharacterAdded == character local respawnou -- devolve a câmera pro jogador.
	self:Cleanup(self.LocalPlayer.CharacterAdded:Connect(function()
		self:StopSpectating()
	end))
end)

return DeathCameraController
