--!strict

local StarterPlayer = game:GetService("StarterPlayer")
local GunBar = require(StarterPlayer.StarterPlayerScripts.client.Weapon.GunBar)

export type Public = {
	PlayerImage: string,
	Unmount: (() -> ())?,
	Setup: (self: Public) -> (),
	SpreadRatio: (self: Public) -> number,
	BuildGunSlots: (self: Public) -> { GunBar.SlotProps },
	Mount: (self: Public, playerGui: Instance, panels: { [string]: Part }) -> (),
}

return {}
