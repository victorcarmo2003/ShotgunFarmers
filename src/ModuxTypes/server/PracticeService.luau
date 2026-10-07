--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)

export type Public = {
	Choices: { [Player]: { [number]: GetGun.GunNames } },
	LastRespawn: { [Player]: number },
	Windows: { [Player]: { Start: number, Count: number } },
	Setup: (self: Public) -> (),
	IsPractice: (self: Public) -> boolean,
	Allow: (self: Public, player: Player) -> boolean,
	Equip: (self: Public, player: Player, gunID: number) -> boolean,
	SetInfinite: (self: Public, player: Player, ammo: boolean, grenades: boolean) -> (),
	Refill: (self: Public, player: Player) -> (),
	Respawn: (self: Public, player: Player) -> (),
	Reapply: (self: Public, player: Player) -> (),
	Forget: (self: Public, player: Player) -> (),
}

return {}
