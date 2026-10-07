--!strict

export type Delta = {
	Xp: number?,
	Kills: number?,
	Deaths: number?,
	Assists: number?,
	Headshots: number?,
	Matches: number?,
	Wins: number?,
}

export type Public = {
	Disposers: { [Player]: () -> () },
	KillLog: { [Player]: { [Player]: { number } } },
	PendingDamage: { [Player]: number },
	Setup: (self: Public) -> (),
	Counts: (self: Public) -> boolean,
	SendState: (self: Public, player: Player) -> (),
	Watch: (self: Public, player: Player) -> (),
	Unwatch: (self: Public, player: Player) -> (),
	Award: (self: Public, player: Player, delta: Delta) -> (),
	RegisterKill: (self: Public, killer: Player, victim: Player) -> boolean,
	OnKilled: (self: Public, killer: Player, victim: Player, isHeadshot: boolean, assisters: { Player }) -> (),
	OnDied: (self: Public, victim: Player) -> (),
	OnDamaged: (self: Public, attacker: Player, _victim: Player, amount: number) -> (),
	FlushDamage: (self: Public) -> (),
	Winners: (self: Public) -> { [Player]: boolean },
	OnMatchEnded: (self: Public) -> (),
	Forget: (self: Public, player: Player) -> (),
}

return {}
