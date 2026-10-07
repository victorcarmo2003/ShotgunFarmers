--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local HitNet = require(ReplicatedStorage.shared.Hit.Net)
local Vide = require(ReplicatedStorage.Packages.Vide)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type FireRequest = {
	Origin: Vector3,
	Direction: Vector3,
	Pellets: { HitNet.Pellet },
	IsAiming: boolean,
	TimeStamp: number,
}

export type Public = {
	Fired: SignalLib.Signal<GetGun.GunData>,
	HitMarkerTrigger: Vide.Source<number>,
	Holding: boolean,
	InFlight: number,
	LastShotTime: number,
	Setup: (self: Public) -> (),
	PlayShotSound: (self: Public, gunData: GetGun.GunData) -> (),
	CanFire: (self: Public) -> boolean,
	Send: (self: Public, request: FireRequest, hitPosition: Vector3?, consumes: boolean, travel: number) -> (),
	Dispatch: (self: Public, request: FireRequest, hitPosition: Vector3?, consumes: boolean, travel: number?) -> (),
	FireHitscan: (self: Public, gunData: GetGun.GunData, origin: Vector3, look: Vector3, now: number) -> (),
	FireMelee: (self: Public, gunData: GetGun.GunData) -> (),
	Strike: (self: Public, gunData: GetGun.GunData) -> (),
	FireCone: (self: Public, gunData: GetGun.GunData, origin: Vector3, look: Vector3, now: number) -> (),
	FireProjectile: (self: Public, gunData: GetGun.GunData, look: Vector3) -> boolean,
	TryHit: (self: Public, pressed: boolean) -> boolean,
	StepHold: (self: Public) -> (),
}

return {}
