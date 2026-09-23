--!strict

export type FOVState = "Run" | "Idle"

export type Public = {
	Aiming: boolean?,
	Style: FOVState?,
	Tween: Tween?,
	Setup: (self: Public) -> (),
	TargetFov: (self: Public, style: FOVState, aiming: boolean) -> number,
	ApplyFov: (self: Public, style: FOVState, aiming: boolean) -> (),
	Step: (self: Public) -> (),
}

return {}
