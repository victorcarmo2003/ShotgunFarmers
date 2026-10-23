--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local BotTypes = require(ServerScriptService.server.Bot.BotTypes)

export type Pellet = { TargetID: number, HitPart: number }
export type Hit = { Target: BotTypes.Fighter, HitPart: number, Distance: number }

export type Public = {
	Instance: Instance,
	GunName: string,
	LastPlant: number,
	LastShoot: number,
	Stats: GetGun.GunData?,
	Setup: (self: Public) -> (),
	Data: (self: Public) -> GetGun.GunData,
	CanShoot: (self: Public, shooter: Player, ammo: number, stamp: number?) -> (boolean, string?),
	MarkShot: (self: Public, stamp: number) -> (),
	CanPlant: (self: Public) -> boolean,
	PlaySound: (self: Public, shooter: Player) -> (),
	Shoot: (self: Public, shooter: Player, origin: Vector3, direction: Vector3, pellets: { Pellet }, timestamp: number, isAiming: boolean) -> { Hit },
	Strike: (self: Public, shooter: Player, origin: Vector3, direction: Vector3, pellets: { Pellet }, timestamp: number) -> { Hit },
	Spray: (self: Public, shooter: Player, origin: Vector3, direction: Vector3, timestamp: number) -> { Hit },
}

return {}
