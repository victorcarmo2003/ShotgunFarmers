--!strict

export type Public = {
	Counted: { [Player]: boolean },
	InMatch: boolean,
	Rounds: { [Player]: number },
	Waiting: { [Player]: { [number]: boolean } },
	Setup: (self: Public) -> (),
	Step: (self: Public, player: Player, step: string, fields: { string }?) -> (),
	OnAnswered: (self: Public, player: Player, from: number, result: string) -> (),
	OnLobbyJoin: (self: Public, arrived: Player) -> (),
	Mates: (self: Public, player: Player) -> { Player },
	OnMatchJoin: (self: Public, player: Player) -> (),
	OnRoundStarted: (self: Public) -> (),
	Activate: (self: Public) -> (),
	Forget: (self: Public, player: Player) -> (),
}

return {}
