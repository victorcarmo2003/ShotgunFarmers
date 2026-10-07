--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ThrowSim = require(ReplicatedStorage.shared.Weapon.ThrowSim)
local Throwables = require(ReplicatedStorage.shared.Weapon.Throwables)

export type ThrowRequest = {
	Origin: Vector3,
	Direction: Vector3,
	Target: Vector3,
	Mode: number,
	TimeStamp: number,
}
export type Projectile = {
	Id: number,
	Owner: Player,
	GunName: string,
	Definition: Throwables.Definition,
	State: ThrowSim.State,
	Params: RaycastParams,
	Plants: boolean,
}
export type Zone = {
	Owner: Player,
	GunName: string,
	Definition: Throwables.Definition,
	Spec: Throwables.ZoneSpec,
	Center: Vector3,
	EndsAt: number,
	NextDamage: number,
}
export type Burn = {
	Owner: Player,
	GunName: string,
	Dps: number,
	EndsAt: number,
	NextDamage: number,
}

export type Public = {
	Accumulator: number,
	Burning: { [Player]: boolean },
	Burns: { [Player]: Burn },
	NextId: number,
	Projectiles: { [number]: Projectile },
	ScanAccumulator: number,
	SightParams: RaycastParams,
	Slowed: { [Player]: boolean },
	Zones: { Zone },
	Setup: (self: Public) -> (),
	AllocateId: (self: Public) -> number,
	IsAlive: (self: Public, player: Player) -> boolean,
	Hurt: (self: Public, owner: Player, victim: Player, amount: number, gunName: string, isHeadshot: boolean?) -> (),
	SafeOrigin: (self: Public, character: Model, requested: Vector3) -> Vector3,
	ProcessThrow: (self: Public, request: ThrowRequest, player: Player) -> (),
	Launch: (self: Public, owner: Player, gunName: string, kind: number, definition: Throwables.Definition, origin: Vector3, velocity: Vector3, curve: number, latency: number) -> (),
	StepProjectile: (self: Public, projectile: Projectile) -> boolean,
	Strike: (self: Public, projectile: Projectile, instance: Instance) -> (),
	CanSee: (self: Public, center: Vector3, character: Model) -> boolean,
	Blast: (self: Public, projectile: Projectile, center: Vector3) -> (),
	Shrapnel: (self: Public, projectile: Projectile, center: Vector3) -> { Vector3 },
	GroundBelow: (self: Public, position: Vector3) -> Vector3,
	Detonate: (self: Public, projectile: Projectile, position: Vector3) -> (),
	Ignite: (self: Public, owner: Player, victim: Player, gunName: string) -> (),
	SyncBurning: (self: Public) -> (),
	SetSlowed: (self: Public, player: Player, multiplier: number?) -> (),
	ScanZones: (self: Public, now: number) -> (),
	Step: (self: Public, deltaTime: number) -> (),
	ClearAll: (self: Public) -> (),
	ForgetPlayer: (self: Public, player: Player) -> (),
	Connect: (self: Public) -> (),
}

return {}
