--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

export type Loadout = {
	Slots: { number },
	ActiveSlot: number,
	Ammo: { number },
	DrawEndsAt: number,
}

export type ThrowSpawn = {
	Id: number,
	Kind: number,
	OwnerID: number,
	Origin: Vector3,
	Velocity: Vector3,
	Curve: number,
	ServerTime: number,
}

export type ThrowDetonate = {
	Id: number,
	Position: Vector3,
	ZoneCenter: Vector3,
	Shards: { Vector3 },
}

export type ShotSound = { ShooterID: number, GunID: number }

return Lync.define("Weapon", {
	Loadout = Lync.packet(Lync.struct({
		Slots = Lync.array(Lync.int(0, 255), 3, 3),
		ActiveSlot = Lync.int(1, 3),

		Ammo = Lync.array(Lync.int(0, 255), 3, 3),

		DrawEndsAt = Lync.f64(),
	})),

	SwitchSlot = Lync.packet(Lync.struct({ Slot = Lync.int(1, 3) })),
	DiscardWeapon = Lync.packet(Lync.empty()),
	Discarded = Lync.packet(Lync.struct({ Gun = Lync.int(0, 255) })),

	Throw = Lync.packet(Lync.struct({
		Origin = Lync.vec3(),
		Direction = Lync.vec3.unit(0.001),
		Target = Lync.vec3(),
		Mode = Lync.int(1, 3),
		TimeStamp = Lync.f64(),
	})),

	ThrowSpawn = Lync.packet(Lync.struct({
		Id = Lync.int(0, 65535),
		Kind = Lync.int(0, 255),
		OwnerID = Lync.int(0, 255),
		Origin = Lync.vec3(),
		Velocity = Lync.vec3(),
		Curve = Lync.f32(),
		ServerTime = Lync.f64(),
	})),

	ThrowDetonate = Lync.packet(Lync.struct({
		Id = Lync.int(0, 65535),
		Position = Lync.vec3(),
		ZoneCenter = Lync.vec3(),
		Shards = Lync.array(Lync.vec3(), 0, 8),
	})),

	ThrowClear = Lync.packet(Lync.empty()),

	ShotSound = Lync.packet(Lync.struct({
		ShooterID = Lync.int(0, 255),
		GunID = Lync.int(0, 255),
	})),
})
