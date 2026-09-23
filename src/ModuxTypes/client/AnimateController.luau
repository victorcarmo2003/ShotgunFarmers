--!strict

export type CoreAnimState = "Idle" | "Walk" | "Run" | "CrouchIdle" | "CrouchWalk" | "Jump" | "Fall" | "Land"

export type Public = {
	Airborne: boolean,
	CurrentState: CoreAnimState?,
	HumanoidStateConnection: RBXScriptConnection?,
	LandHoldUntil: number,
	LastMovingClock: number,
	TrackedHumanoid: Humanoid?,
	Tracks: { [CoreAnimState]: AnimationTrack? }?,
	Setup: (self: Public) -> (),
	ClearTracks: (self: Public) -> (),
	LoadTracks: (self: Public, animator: Animator) -> (),
	Attach: (self: Public, humanoid: Humanoid?) -> (),
	SetState: (self: Public, state: CoreAnimState) -> (),
	StopAll: (self: Public) -> (),
	ComputeBaseState: (self: Public) -> CoreAnimState,
	OnHumanoidStateChanged: (self: Public, state: Enum.HumanoidStateType) -> (),
}

return {}
