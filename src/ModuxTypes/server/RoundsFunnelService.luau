--!strict

export type Public = {
	Active: boolean,
	Outcomes: { [Player]: string },
	Rounds: { [Player]: number },
	Setup: (self: Public) -> (),
	Step: (self: Public, player: Player, step: string, fields: { string }?) -> (),
	Mix: (self: Public) -> string,
	Join: (self: Public, player: Player) -> (),
	Resolved: (self: Public, player: Player, outcome: string, placement: number, total: number, sent: boolean) -> (),
	RoundStarted: (self: Public) -> (),
	Leave: (self: Public, player: Player, reason: string) -> (),
	Activate: (self: Public) -> (),
}

return {}
