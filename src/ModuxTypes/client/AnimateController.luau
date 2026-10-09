--!strict

export type CoreAnimState =
	"Idle"
	| "Walk"
	| "WalkBackward"
	| "Run"
	| "RunBackward"
	| "CrouchIdle"
	| "CrouchWalk"
	| "CrouchWalkForward"
	| "CrouchWalkBackward"
	| "Jump"
	| "Fall"
	| "Land"

export type Public = {
	Airborne: boolean,
	CurrentState: CoreAnimState?,
	GunName: string?,
	HumanoidStateConnection: RBXScriptConnection?,
	LandHoldUntil: number,
	LastMovingClock: number,
	TrackedHumanoid: Humanoid?,
	Tracks: { [CoreAnimState]: AnimationTrack? }?,
	Setup: (self: Public) -> (),
	EquippedGun: (self: Public) -> string?,
	ClearTracks: (self: Public) -> (),
	LoadTracks: (self: Public, animator: Animator) -> (),
	Attach: (self: Public, humanoid: Humanoid?) -> (),
	SetState: (self: Public, state: CoreAnimState) -> (),
	StopAll: (self: Public) -> (),
	ComputeBaseState: (self: Public) -> CoreAnimState,
	Prefer: (self: Public, state: CoreAnimState, fallback: CoreAnimState) -> CoreAnimState,
	OnHumanoidStateChanged: (self: Public, state: Enum.HumanoidStateType) -> (),
}

return {}
