local Modux = require(game.ReplicatedStorage.Shared.Modux)

local SnapshotController = Modux.Controller("SnapshotController"):Import("CameraController"):Import("MovementController")

-- Mesma ordem de src/server/Components/Player/MovementComponent.luau (MovementStates),
-- só que numérica pra caber no pacote (Network.int(0,7)). Ninguém consome esse valor
-- ainda -- é reservado pra reconciliação/anti-cheat futuros.
local STATE_IDS = {
	Walking = 0,
	Running = 1,
	Crouch = 2,
	Sliding = 3,
	Jumping = 4,
	Dead = 5,
}

local function toVector3int16(v: Vector3): Vector3int16
	return Vector3int16.new(math.round(v.X), math.round(v.Y), math.round(v.Z))
end

-- Modux.TickScheduler tem MAX_CATCH_UP = 3: se o frame rate cair, o OnTick abaixo
-- pode disparar 2-3x no mesmo Heartbeat antes do próximo flush do lync. Isso força
-- o pacote PlayerSnapshot a virar um batch multi-item -- caminho que nunca teve
-- tráfego real antes de existir esse controller. Esse guard garante no máximo 1
-- envio real por ~1 frame de 60Hz, absorvendo o catch-up sem depender de mexer no
-- transporte de rede.
local MIN_SEND_INTERVAL = (1 / 60) * 0.75
local lastSendClock = 0

SnapshotController.GetCurrentState = function(self): number
	if self.MovementController.IsSliding then
		return STATE_IDS.Sliding
	end

	local humanoid = self.LocalHumanoid
	if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		return STATE_IDS.Jumping
	end

	if humanoid and humanoid.WalkSpeed <= 15 then
		return STATE_IDS.Crouch
	end

	local moveDirection = self.MovementController:GetMoveDirection()
	if moveDirection and moveDirection.Magnitude > 0 then
		return STATE_IDS.Running
	end

	return STATE_IDS.Walking
end

SnapshotController.SendSnapshot = function(self)
	local now = os.clock()
	if now - lastSendClock < MIN_SEND_INTERVAL then
		return
	end
	lastSendClock = now

	local character = self.LocalCharacter
	local primaryPart = character and character.PrimaryPart
	if not primaryPart then
		return
	end

	local lookAt = self.CameraController:GetLookAt() or primaryPart.Position
	local moveDirection = self.MovementController:GetMoveDirection() or Vector3.zero

	self.Network.Packages.PlayerSnapshot:send({
		Position = toVector3int16(primaryPart.Position),
		LookAt = toVector3int16(lookAt),
		State = self:GetCurrentState(),
		MoveDir = Vector2.new(moveDirection.X, moveDirection.Z),
		WeaponID = 0, -- TODO: popular quando a cadeia de arma (EquipmentComponent) existir
		Timestamp = workspace:GetServerTimeNow(),
	})
end

SnapshotController:OnTick(function(self, deltaTime: number)
	self:SendSnapshot()
end, Modux.TickRate.Hz60)

return SnapshotController
