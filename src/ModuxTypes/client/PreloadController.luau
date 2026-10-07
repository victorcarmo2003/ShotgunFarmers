--!strict

export type Public = {
	Animations: { Animation },
	Done: boolean,
	Setup: (self: Public) -> (),
	AnimationInstances: (self: Public) -> { Animation },
	Run: (self: Public) -> (),
}

return {}
