local Modux = require(game.ReplicatedStorage.Shared.Modux)

local SnapshotController =
	Modux.Controller("SnapshotController"):Import("CameraController"):Import("MovementController")
type Self = typeof(SnapshotController)

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

local MIN_SEND_INTERVAL = (1 / 60) * 0.75
local lastSendClock = 0

SnapshotController.GetCurrentState = function(self: Self): number
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

SnapshotController.SendSnapshot = function(self: Self)
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
		WeaponID = 0,
		Timestamp = workspace:GetServerTimeNow(),
	})
end

SnapshotController:OnTick(function(self, deltaTime: number)
	self:SendSnapshot()
end, Modux.TickRate.Hz60)

return SnapshotController
