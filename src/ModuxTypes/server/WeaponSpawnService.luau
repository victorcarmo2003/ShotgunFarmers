--!strict

export type Public = {
	Enabled: boolean,
	Pool: { string },
	Spawned: { BasePart },
	Warned: boolean,
	Setup: (self: Public) -> (),
	BuildPool: (self: Public) -> (),
	Candidates: (self: Public) -> { BasePart },
	Prune: (self: Public) -> (),
	FarFromOthers: (self: Public, point: Vector3) -> boolean,
	SpawnOne: (self: Public) -> boolean,
	Fill: (self: Public, limit: number) -> (),
	Clear: (self: Public) -> (),
	Refresh: (self: Public) -> (),
}

return {}
