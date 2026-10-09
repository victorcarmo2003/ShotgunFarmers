--!strict

export type Public = {
	Frozen: boolean,
	Setup: (self: Public) -> (),
	ShouldFreeze: (self: Public) -> boolean,
	Apply: (self: Public, character: Model) -> (),
	ApplyAll: (self: Public) -> (),
	Refresh: (self: Public) -> (),
}

return {}
