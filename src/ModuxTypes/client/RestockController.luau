--!strict

export type Public = {
	Highlight: Highlight,
	Target: Instance?,
	Setup: (self: Public) -> (),
	NeedsWeapon: (self: Public) -> boolean,
	Nearest: (self: Public, origin: Vector3) -> Instance?,
	SetTarget: (self: Public, crate: Instance?) -> (),
	Step: (self: Public) -> (),
}

return {}
