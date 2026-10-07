--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local StatsNet = require(ReplicatedStorage.shared.Stats.Net)

export type PlayerStats = {
	Kills: number,
	Deaths: number,
	Assists: number,
	Headshots: number,
	Score: number,
	Damage: number,
	Ping: number,
}
export type Totals = { Red: number, Blue: number }

export type Public = {
	Active: boolean,
	Damaged: SignalLib.Signal<Player, Player, number>,
	Died: SignalLib.Signal<Player>,
	Killed: SignalLib.Signal<Player, Player, boolean, { Player }>,
	MatchEnded: SignalLib.Signal<>,
	MatchStarted: SignalLib.Signal<>,
	Pending: { [Player]: { [Player]: boolean } },
	Stats: { [Player]: PlayerStats },
	Totals: Totals,
	Setup: (self: Public) -> (),
	IsActive: (self: Public) -> boolean,
	Get: (self: Public, player: Player) -> PlayerStats?,
	TeamOf: (self: Public, player: Player) -> StatsNet.Team,
	PushRow: (self: Public, player: Player) -> (),
	PublishTotals: (self: Public, to: Lync.Recipient) -> (),
	RecomputeTotals: (self: Public) -> (),
	Add: (self: Public, player: Player) -> (),
	Medal: (self: Public, killer: Player, isHeadshot: boolean) -> (),
	Remove: (self: Public, player: Player) -> (),
	Reset: (self: Public) -> (),
	Activate: (self: Public) -> (),
	ClearPending: (self: Public, victim: Player) -> (),
	RecordDamage: (self: Public, attacker: Player, victim: Player, amount: number) -> (),
	RecordKill: (self: Public, killer: Player, victim: Player, isHeadshot: boolean) -> (),
	RecordDeath: (self: Public, victim: Player) -> (),
	UpdatePing: (self: Public) -> (),
}

return {}
