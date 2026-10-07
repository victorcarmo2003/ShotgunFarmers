--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local GunBar = require(StarterPlayer.StarterPlayerScripts.client.Weapon.GunBar)

export type Public = {
	Bloom: Vide.Source<number>,
	PlayerImage: Vide.Source<string>,
	Unmount: (() -> ())?,
	Setup: (self: Public) -> (),
	AddBloom: (self: Public) -> (),
	StepBloom: (self: Public, deltaTime: number) -> (),
	BuildGunSlots: (self: Public) -> { GunBar.SlotProps },
	Mount: (self: Public, playerGui: Instance, panels: { [string]: Part }) -> (),
}

return {}
