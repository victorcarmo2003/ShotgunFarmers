--!strict

export type Public = {
	Params: RaycastParams,
	Setup: (self: Public) -> (),
	Mark: (self: Public, instance: Instance) -> (),
	Touching: (self: Public, feet: Vector3, lava: { Instance }) -> boolean,
	IsOnLava: (self: Public, character: Model, lava: { Instance }) -> boolean,
	Step: (self: Public) -> (),
}

return {}
