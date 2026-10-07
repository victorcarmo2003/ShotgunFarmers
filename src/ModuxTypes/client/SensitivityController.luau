--!strict

export type Public = {
	Applied: number?,
	Setup: (self: Public) -> (),
	Multiplier: (self: Public) -> number,
	Step: (self: Public) -> (),
}

return {}
