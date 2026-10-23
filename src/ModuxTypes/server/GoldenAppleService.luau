--!strict

export type Public = {
	Apples: { BasePart },
	Enabled: boolean,
	NextAt: number,
	Setup: (self: Public) -> (),
	Eat: (self: Public, player: Player) -> boolean,
	SpawnAt: (self: Public, point: Vector3) -> BasePart?,
	SpawnOne: (self: Public) -> boolean,
	Prune: (self: Public) -> (),
	Clear: (self: Public) -> (),
	Step: (self: Public) -> (),
}

return {}
