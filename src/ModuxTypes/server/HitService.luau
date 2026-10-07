--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HitNet = require(ReplicatedStorage.shared.Hit.Net)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)

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
export type ResolvedHit = { Player: Player, HitPart: number, Distance: number }

export type Public = {
	Budget: { [Player]: FireBudget },
	Burned: SignalLib.Signal<Player, Player, string>,
	Setup: (self: Public) -> (),
	SpendFireToken: (self: Public, player: Player) -> boolean,
	DealDamage: (self: Public, shooter: Player, target: Player, damage: number) -> (boolean, boolean),
	ApplyKnockback: (self: Public, root: BasePart, direction: Vector3, force: number) -> (),
	Announce: (self: Public, shooter: Player, victim: Player, gunName: string, isHeadshot: boolean) -> (),
	BroadcastShot: (self: Public, shooter: Player, gunData: GetGun.GunData, origin: Vector3, direction: Vector3) -> (),
	ResolvePellet: (self: Public, shooter: Player, origin: Vector3, direction: Vector3, claimedTargetID: number, claimedHitPart: number, timestamp: number, range: number, hitbox: number?) -> (boolean, Player?, number?, number?),
	ConeTargets: (self: Public, shooter: Player, origin: Vector3, direction: Vector3, range: number, angle: number, timestamp: number) -> { ResolvedHit },
	HitDamage: (self: Public, gunData: GetGun.GunData, hit: ResolvedHit) -> number,
	ApplyHit: (self: Public, shooter: Player, hit: ResolvedHit, gunData: GetGun.GunData, gunName: string, origin: Vector3) -> (),
	ProcessFire: (self: Public, request: FireRequest, shooter: Player) -> FireReply,
}

return {}
