--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local HitNet = require(ReplicatedStorage.shared.Hit.Net)
local WeaponNet = require(ReplicatedStorage.shared.Weapon.Net)
local WeaponVFX = require(ReplicatedStorage.shared.Weapon.WeaponVFX)

export type Vitals = { Health: number, Armor: number, Stamina: number }
export type BurstPool = { Parts: { BasePart }, Bursts: { [BasePart]: { Burst } }, Next: number }
export type MuzzleRig = { Attachments: { Attachment }, Bursts: { Burst } }
export type PendingShot = {
	GunData: GetGun.GunData,
	Model: Model?,
	Forward: Vector3,
	Direction: Vector3,
	Fallback: Vector3,
	Pellets: { WeaponVFX.Pellet },
	Viewmodel: boolean,
	Flame: boolean,
}
export type Screen = { Part: BasePart, Loops: { ParticleEmitter }, Bursts: { Burst }, ActiveUntil: number, Looping: boolean }
export type Burst = { Emitter: ParticleEmitter, Count: number }

export type Public = {
	Budget: number,
	Burning: boolean,
	Muzzles: any,
	Pending: { PendingShot },
	Pools: { [string]: BurstPool },
	Screens: { [string]: Screen },
	Setup: (self: Public) -> (),
	Spend: (self: Public) -> boolean,
	PoolFor: (self: Public, name: string) -> BurstPool?,
	BurstAt: (self: Public, name: string, frame: CFrame) -> (),
	RigMuzzle: (self: Public, model: Model, forward: Vector3, templateName: string, viewmodel: boolean, locked: boolean) -> MuzzleRig?,
	EmitMuzzle: (self: Public, model: Model?, forward: Vector3, templateName: string?, viewmodel: boolean) -> (),
	MuzzleOrigin: (self: Public, model: Model?, forward: Vector3, fallback: Vector3) -> Vector3,
	Impact: (self: Public, set: WeaponVFX.Set, pellet: WeaponVFX.Pellet) -> (),
	PlayShot: (self: Public, gunData: GetGun.GunData, model: Model?, forward: Vector3, start: Vector3, pellets: { WeaponVFX.Pellet }, viewmodel: boolean) -> (),
	PlayFlame: (self: Public, gunData: GetGun.GunData, model: Model?, origin: Vector3, forward: Vector3, viewmodel: boolean) -> (),
	Queue: (self: Public, shot: PendingShot) -> (),
	FlushShots: (self: Public) -> (),
	LocalModel: (self: Public, gunData: GetGun.GunData) -> (Model?, boolean),
	LocalShot: (self: Public, gunData: GetGun.GunData, forward: Vector3, start: Vector3, pellets: { WeaponVFX.Pellet }) -> (),
	LocalFlame: (self: Public, gunData: GetGun.GunData, origin: Vector3, forward: Vector3) -> (),
	OnShotSound: (self: Public, packet: WeaponNet.ShotSound) -> (),
	OnRemoteShot: (self: Public, packet: HitNet.Shot) -> (),
	OnRemoteLaunch: (self: Public, packet: WeaponNet.ThrowSpawn) -> (),
	AttachTrail: (self: Public, visual: Model, gunName: string) -> (),
	DetachTrail: (self: Public, visual: Model) -> (),
	ScreenFor: (self: Public, name: string) -> Screen?,
	PlaceScreen: (self: Public, screen: Screen, camera: Camera) -> (),
	ScreenBurst: (self: Public, name: string) -> (),
	SetBurning: (self: Public, burning: boolean) -> (),
	StepScreens: (self: Public) -> (),
	HealBurst: (self: Public, player: Player) -> (),
	OnVitals: (self: Public, userId: number, record: Vitals, previous: Vitals?) -> (),
	WatchBurning: (self: Public) -> (),
}

return {}
