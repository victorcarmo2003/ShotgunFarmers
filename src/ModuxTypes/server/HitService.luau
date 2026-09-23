--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HitNet = require(ReplicatedStorage.shared.Hit.Net)

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

export type Public = {
	Budget: { [Player]: FireBudget },
	Setup: (self: Public) -> (),
	SpendFireToken: (self: Public, player: Player) -> boolean,
	DealDamage: (self: Public, target: Player, damage: number) -> boolean,
	ApplyKnockback: (self: Public, root: BasePart, direction: Vector3, force: number) -> (),
	Announce: (self: Public, shooter: Player, victim: Player, gunName: string, isHeadshot: boolean) -> (),
	ResolvePellet: (self: Public, shooter: Player, origin: Vector3, direction: Vector3, claimedTargetID: number, claimedHitPart: number, timestamp: number) -> (boolean, Player?, number?),
	ProcessFire: (self: Public, request: FireRequest, shooter: Player) -> FireReply,
}

return {}
