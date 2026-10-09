--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponSounds = require(ReplicatedStorage.shared.Weapon.WeaponSounds)

export type Delta = {
	Xp: number?,
	Kills: number?,
	Deaths: number?,
	Assists: number?,
	Headshots: number?,
	Matches: number?,
	Wins: number?,
	Gems: number?,
}
export type Session = { Xp: number, Gems: number, StartLevel: number }

export type Public = {
	Disposers: { [Player]: () -> () },
	KillLog: { [Player]: { [Player]: { number } } },
	PendingDamage: { [Player]: number },
	Sessions: { [Player]: Session },
	Setup: (self: Public) -> (),
	SessionOf: (self: Public, player: Player, level: number) -> Session,
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
	Placements: (self: Public) -> { [Player]: number },
	SendSummary: (self: Public, player: Player, outcome: WeaponSounds.Outcome, placements: { [Player]: number }, counted: boolean) -> (),
	Forget: (self: Public, player: Player) -> (),
}

return {}
