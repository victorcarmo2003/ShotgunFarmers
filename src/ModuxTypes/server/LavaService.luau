--!strict

export type Public = {
	Params: OverlapParams,
	Setup: (self: Public) -> (),
	IsOnLava: (self: Public, character: Model, lava: { Instance }) -> boolean,
	Step: (self: Public) -> (),
}

return {}
