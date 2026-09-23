--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WeaponNet = require(ReplicatedStorage.shared.Weapon.Net)

export type Loadout = WeaponNet.Loadout

export type Public = {
	ActiveSlot: Vide.Source<number>,
	Ammo: Vide.Source<{ number }>,
	DrawEnded: SignalLib.Signal<number>,
	DrawEndsAt: Vide.Source<number>,
	DrawGeneration: number,
	Slots: Vide.Source<{ number }>,
	Setup: (self: Public) -> (),
	WeaponID: (self: Public) -> number,
	GunData: (self: Public) -> GetGun.GunData?,
	SlotGun: (self: Public, slot: number) -> GetGun.GunData?,
	ActiveAmmo: (self: Public) -> number,
	IsDrawing: (self: Public) -> boolean,
	WatchDraw: (self: Public, endsAt: number) -> (),
	Apply: (self: Public, loadout: Loadout) -> (),
	SwitchSlot: (self: Public, slot: number) -> (),
	BindKeys: (self: Public) -> (),
}

return {}
