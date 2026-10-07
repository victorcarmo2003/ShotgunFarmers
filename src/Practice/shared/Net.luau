--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

return Lync.define("Practice", {
	Equip = Lync.packet(Lync.struct({ Gun = Lync.int(0, 255) })),

	SetInfinite = Lync.packet(Lync.struct({
		Ammo = Lync.bool(),
		Grenades = Lync.bool(),
	})),

	Refill = Lync.packet(Lync.empty()),
	Respawn = Lync.packet(Lync.empty()),
})
