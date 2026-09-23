--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

export type Pellet = { TargetID: number, HitPart: number }

return Lync.define("Hit", {
	Fire = Lync.query(
		Lync.struct({
			Origin = Lync.vec3(Lync.quant(-4096, 4096, 0.25)),
			Direction = Lync.vec3.unit(0.001),
			Pellets = Lync.array(
				Lync.struct({
					TargetID = Lync.int(0, 255),
					HitPart = Lync.int(0, 15),
				}),
				0,
				12
			),
			IsAiming = Lync.bool(),
			TimeStamp = Lync.f64(),
		}),
		Lync.struct({
			Accepted = Lync.bool(),
			Hits = Lync.int(0, 12),
		})
	),
})
