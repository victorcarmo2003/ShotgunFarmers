--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterNet = require(ReplicatedStorage.shared.Character.Net)

export type SnapshotFrame = {
	Position: Vector3,
	LookAt: Vector3,
	State: MovementState,
	MoveDir: Vector2,
	WeaponID: number,
	Timestamp: number,
}
type MovementState = CharacterNet.MovementState

export type Public = {
	History: { [number]: { SnapshotFrame } },
	Recorded: { [Player]: number },
	Setup: (self: Public) -> (),
	RegisterSnapshot: (self: Public, player: Player, frame: SnapshotFrame) -> (),
	GetHistory: (self: Public, targetID: number) -> { SnapshotFrame }?,
	GetRewoundPosition: (self: Public, targetID: number, atTime: number) -> Vector3?,
	ClearHistory: (self: Public, targetID: number) -> (),
	Prune: (self: Public) -> (),
}

return {}
