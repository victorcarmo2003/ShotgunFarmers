--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Lync = require(ReplicatedStorage.Packages.Lync)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local StatsNet = require(ReplicatedStorage.shared.Stats.Net)
local BotTypes = require(ServerScriptService.server.Bot.BotTypes)

type Fighter = BotTypes.Fighter
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
	Damaged: SignalLib.Signal<Fighter, Fighter, number>,
	Died: SignalLib.Signal<Fighter>,
	Killed: SignalLib.Signal<Fighter, Fighter, boolean, { Fighter }>,
	MatchEnded: SignalLib.Signal<>,
	MatchStarted: SignalLib.Signal<>,
	Pending: { [Fighter]: { [Fighter]: boolean } },
	Stats: { [Fighter]: PlayerStats },
	Totals: Totals,
	Setup: (self: Public) -> (),
	IsActive: (self: Public) -> boolean,
	Get: (self: Public, fighter: Fighter) -> PlayerStats?,
	TeamOf: (self: Public, fighter: Fighter) -> StatsNet.Team,
	PushRow: (self: Public, fighter: Fighter) -> (),
	PublishTotals: (self: Public, to: Lync.Recipient) -> (),
	RecomputeTotals: (self: Public) -> (),
	Add: (self: Public, fighter: Fighter) -> (),
	Medal: (self: Public, killer: Fighter, isHeadshot: boolean) -> (),
	Remove: (self: Public, fighter: Fighter) -> (),
	Reset: (self: Public) -> (),
	Activate: (self: Public) -> (),
	ClearPending: (self: Public, victim: Fighter) -> (),
	RecordDamage: (self: Public, attacker: Fighter, victim: Fighter, amount: number) -> (),
	RecordKill: (self: Public, killer: Fighter, victim: Fighter, isHeadshot: boolean) -> (),
	RecordDeath: (self: Public, victim: Fighter) -> (),
	UpdatePing: (self: Public) -> (),
}

return {}
