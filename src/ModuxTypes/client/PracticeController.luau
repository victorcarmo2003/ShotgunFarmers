--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	InfiniteAmmo: Vide.Source<boolean>,
	InfiniteGrenades: Vide.Source<boolean>,
	Opened: Vide.Source<boolean>,
	Unmount: (() -> ())?,
	Setup: (self: Public) -> (),
	IsPractice: (self: Public) -> boolean,
	SetOpen: (self: Public, open: boolean) -> (),
	Toggle: (self: Public) -> (),
	Refresh: (self: Public) -> (),
	ReadInfinite: (self: Public) -> (),
	Select: (self: Public, id: number) -> (),
	SendInfinite: (self: Public, ammo: boolean, grenades: boolean) -> (),
	ToggleAmmo: (self: Public) -> (),
	ToggleGrenades: (self: Public) -> (),
	Refill: (self: Public) -> (),
	Respawn: (self: Public) -> (),
	Mount: (self: Public) -> (),
}

return {}
