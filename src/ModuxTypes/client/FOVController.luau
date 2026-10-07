--!strict

export type FOVState = "Run" | "Idle"

export type Public = {
	Aiming: boolean?,
	BaseFov: number?,
	MenuDelta: number?,
	ScopeFov: number?,
	Style: FOVState?,
	Tween: Tween?,
	Setup: (self: Public) -> (),
	TargetFov: (self: Public, style: FOVState, aiming: boolean, menuDelta: number, scopeFov: number?) -> number,
	ApplyFov: (self: Public, style: FOVState, aiming: boolean, menuDelta: number, scopeFov: number?, info: TweenInfo) -> (),
	Step: (self: Public) -> (),
}

return {}
