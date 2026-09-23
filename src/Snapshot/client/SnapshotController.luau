--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local CharacterNet = require(ReplicatedStorage.shared.Character.Net)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

type MovementState = CharacterNet.MovementState

const LOOK_DISTANCE = 150

const CROUCH_MAX_SPEED = 15

const SnapshotController = Modux.Controller("SnapshotController", {
	Require = { "MovementController", "WeaponController" },
	Priority = 440,
})

local function lookAtFrom(fallback: Vector3): Vector3
	const camera = workspace.CurrentCamera
	if not camera then
		return fallback
	end

	return camera.CFrame.Position + camera.CFrame.LookVector * LOOK_DISTANCE
end

function SnapshotController:GetCurrentState(): MovementState
	const movement = self.Dependencies.MovementController
	if movement.IsSliding then
		return "Sliding"
	end

	const humanoid = movement.Humanoid
	if humanoid then
		if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
			return "Jumping"
		end
		if humanoid.WalkSpeed <= CROUCH_MAX_SPEED then
			return "Crouch"
		end
	end

	return if movement:GetMoveDirection().Magnitude > 0 then "Running" else "Walking"
end

function SnapshotController:SendSnapshot()
	const movement = self.Dependencies.MovementController
	const position = movement:GetCurrentPosition()
	if not position then
		return
	end

	const moveDirection = movement:GetMoveDirection()

	self.Libs.Net.Snapshot.Frame:fireServer({
		Position = position,
		LookAt = lookAtFrom(position),
		State = self:GetCurrentState(),
		MoveDir = Vector2.new(moveDirection.X, moveDirection.Z),
		WeaponID = self.Dependencies.WeaponController:WeaponID(),
		Timestamp = workspace:GetServerTimeNow(),
	})
end

SnapshotController:OnTick(function(self)
	self:SendSnapshot()
end, 60)

return SnapshotController
