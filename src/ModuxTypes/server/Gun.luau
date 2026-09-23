--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)

export type Pellet = { TargetID: number, HitPart: number }
export type Hit = { Player: Player, HitPart: number }

export type Public = {
	Instance: Instance,
	GunName: string,
	LastShoot: number,
	Stats: GetGun.GunData?,
	Setup: (self: Public) -> (),
	Data: (self: Public) -> GetGun.GunData,
	CanShoot: (self: Public, shooter: Player, ammo: number) -> (boolean, string?),
	Shoot: (self: Public, shooter: Player, origin: Vector3, direction: Vector3, pellets: { Pellet }, timestamp: number, isAiming: boolean) -> { Hit },
}

return {}
