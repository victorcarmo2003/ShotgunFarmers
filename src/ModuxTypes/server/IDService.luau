--!strict

export type Public = {
	IDPlayers: { [number]: Player },
	NextID: number,
	PlayerIDs: { [Player]: number },
	Setup: (self: Public) -> (),
	GetNextID: (self: Public) -> number,
	RegisterPlayer: (self: Public, player: Player) -> number,
	GetPlayerID: (self: Public, player: Player) -> number,
	GetPlayerFromID: (self: Public, id: number) -> Player?,
	Unregister: (self: Public, player: Player) -> (),
}

return {}
