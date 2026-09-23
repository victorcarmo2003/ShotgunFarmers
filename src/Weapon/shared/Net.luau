--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

export type Loadout = {
	Slots: { number },
	ActiveSlot: number,
	Ammo: { number },
	DrawEndsAt: number,
}

return Lync.define("Weapon", {
	Loadout = Lync.packet(Lync.struct({
		Slots = Lync.array(Lync.int(0, 255), 3, 3),
		ActiveSlot = Lync.int(1, 3),

		Ammo = Lync.array(Lync.int(0, 255), 3, 3),

		DrawEndsAt = Lync.f64(),
	})),

	SwitchSlot = Lync.packet(Lync.struct({ Slot = Lync.int(1, 3) })),
	DiscardWeapon = Lync.packet(Lync.empty()),
})
