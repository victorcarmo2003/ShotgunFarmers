--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

return Lync.define("Snapshot", {
	Frame = Lync.packet(Lync.struct({
		Position = Lync.vec3(Lync.quant(-4096, 4096, 0.25)),
		LookAt = Lync.vec3(Lync.quant(-4096, 4096, 0.25)),
		State = Lync.enum({ "Walking", "Running", "Crouch", "Sliding", "Jumping", "Dead" }),
		MoveDir = Lync.vec2(Lync.quant(-1, 1, 0.001)),
		WeaponID = Lync.int(0, 255),
		Timestamp = Lync.f64(),
	})):newest(60),
})
