--!strict

export type Public = {
	GetSpawnPoints: (self: Public) -> { BasePart },
	PlaceCharacter: (self: Public, character: Model) -> (),
	SpawnPlayer: (self: Public, player: Player) -> (),
}

return {}
