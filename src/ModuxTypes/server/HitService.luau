--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HitNet = require(ReplicatedStorage.shared.Hit.Net)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local BotTypes = require(ServerScriptService.server.Bot.BotTypes)

type Fighter = BotTypes.Fighter
export type FireRequest = {
	Origin: Vector3,
	Direction: Vector3,
	Pellets: { HitNet.Pellet },
	IsAiming: boolean,
	TimeStamp: number,
}
export type FireReply = {
	Accepted: boolean,
	Hits: number,
}
export type FireBudget = {
	Tokens: number,
	At: number,
}
export type ResolvedHit = { Target: Fighter, HitPart: number, Distance: number }
type Candidate = { Fighter: Fighter, ID: number, Root: Vector3, Character: Model? }

export type Public = {
	Budget: { [Player]: FireBudget },
	Burned: SignalLib.Signal<Player, Player, string>,
	Setup: (self: Public) -> (),
	IDOf: (self: Public, fighter: Fighter) -> number,
	IsAlive: (self: Public, fighter: Fighter) -> boolean,
	Candidates: (self: Public, shooter: Fighter) -> { Candidate },
	SpendFireToken: (self: Public, player: Player) -> boolean,
	DealDamage: (self: Public, shooter: Fighter, target: Fighter, damage: number) -> (boolean, boolean),
	NotifyDamaged: (self: Public, shooter: Fighter, target: Player, amount: number) -> (),
	ApplyKnockback: (self: Public, root: BasePart, direction: Vector3, force: number) -> (),
	Announce: (self: Public, shooter: Fighter, victim: Fighter, gunName: string, isHeadshot: boolean) -> (),
	BroadcastShot: (self: Public, shooter: Fighter, gunData: GetGun.GunData, origin: Vector3, direction: Vector3) -> (),
	ResolvePellet: (self: Public, shooter: Player, origin: Vector3, direction: Vector3, claimedTargetID: number, claimedHitPart: number, timestamp: number, range: number, hitbox: number?, gunData: GetGun.GunData?) -> (boolean, Fighter?, number?, number?),
	ConeTargets: (self: Public, shooter: Player, origin: Vector3, direction: Vector3, range: number, angle: number, timestamp: number) -> { ResolvedHit },
	HitDamage: (self: Public, gunData: GetGun.GunData, hit: ResolvedHit) -> number,
	ApplyHit: (self: Public, shooter: Fighter, hit: ResolvedHit, gunData: GetGun.GunData, gunName: string, origin: Vector3) -> (),
	ApplyHits: (self: Public, shooter: Fighter, hits: { ResolvedHit }, gunData: GetGun.GunData, gunName: string, origin: Vector3) -> number,
	ProcessFire: (self: Public, request: FireRequest, shooter: Player) -> FireReply,
}

return {}
