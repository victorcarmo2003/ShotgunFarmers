--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)

export type SlotIndex = number

export type Public = {
	Instance: Instance,
	ActiveSlot: SlotIndex,
	Ammo: { number },
	Destroyed: boolean,
	DiscardTokens: { [SlotIndex]: number },
	DrawUntil: number,
	Equipped: GetGun.GunNames?,
	Loadout: { [SlotIndex]: GetGun.GunNames },
	Owner: Player,
	Visual: Model?,
	WeaponID: number,
	Weapons: { [SlotIndex]: Model },
	Setup: (self: Public) -> (),
	Publish: (self: Public) -> (),
	ActiveGun: (self: Public) -> (Instance?, string?),
	ActiveAmmo: (self: Public) -> number,
	IsInfinite: (self: Public, slot: SlotIndex) -> boolean,
	Refill: (self: Public) -> (),
	ConsumeAmmo: (self: Public, amount: number) -> boolean,
	DrawEndsAt: (self: Public) -> number,
	StartDraw: (self: Public, gunData: GetGun.GunData?) -> (),
	ResetAmmo: (self: Public) -> (),
	AddAmmo: (self: Public, gunName: string, amount: number) -> (),
	HasGun: (self: Public, gunName: string) -> boolean,
	RefreshVisual: (self: Public) -> (),
	MountVisual: (self: Public, character: Model, gunName: GetGun.GunNames, gunData: GetGun.GunData) -> (),
	Spawn: (self: Public, gunName: GetGun.GunNames) -> Model,
	Clear: (self: Public, slot: SlotIndex) -> (),
	Equip: (self: Public, slot: SlotIndex) -> boolean,
	SwitchSlot: (self: Public, slot: SlotIndex) -> boolean,
	SlotFor: (self: Public, gunName: string) -> SlotIndex?,
	SetSlot: (self: Public, gunName: GetGun.GunNames, focus: boolean) -> boolean,
	Grant: (self: Public, gunName: GetGun.GunNames) -> boolean,
	DiscardActive: (self: Public) -> boolean,
	Respawn: (self: Public) -> (),
}

return {}
