--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local WeaponSounds = require(ReplicatedStorage.shared.Weapon.WeaponSounds)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local BotTypes = require(ServerScriptService.server.Bot.BotTypes)

type Fighter = BotTypes.Fighter
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
	KillLog: { [Player]: { [Fighter]: { number } } },
	PendingDamage: { [Player]: number },
	Resolved: SignalLib.Signal<Player, WeaponSounds.Outcome, number, number, boolean>,
	Sessions: { [Player]: Session },
	Setup: (self: Public) -> (),
	SessionOf: (self: Public, player: Player, level: number) -> Session,
	Counts: (self: Public) -> boolean,
	SendState: (self: Public, player: Player) -> (),
	Watch: (self: Public, player: Player) -> (),
	Unwatch: (self: Public, player: Player) -> (),
	Award: (self: Public, player: Player, delta: Delta) -> (),
	RegisterKill: (self: Public, killer: Player, victim: Fighter) -> boolean,
	OnKilled: (self: Public, killerFighter: Fighter, victim: Fighter, isHeadshot: boolean, assisters: { Fighter }) -> (),
	OnDied: (self: Public, fighter: Fighter) -> (),
	OnDamaged: (self: Public, fighter: Fighter, _victim: Fighter, amount: number) -> (),
	FlushDamage: (self: Public) -> (),
	Winners: (self: Public) -> { [Player]: boolean },
	OnMatchEnded: (self: Public) -> (),
	Placements: (self: Public) -> { [Fighter]: number },
	CountPlaced: (self: Public, placements: { [Fighter]: number }) -> number,
	SendSummary: (self: Public, player: Player, outcome: WeaponSounds.Outcome, placements: { [Fighter]: number }, counted: boolean) -> boolean,
	Forget: (self: Public, player: Player) -> (),
}

return {}
