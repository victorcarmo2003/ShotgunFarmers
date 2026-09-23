--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)

export type Public = {
	Instance: Instance,
	GunData: GetGun.GunData?,
	GunName: string,
	Harvested: boolean,
	PlantedAt: number,
	Prompt: ProximityPrompt?,
	Trigger: RBXScriptConnection?,
	Setup: (self: Public) -> (),
	Collect: (self: Public, player: Player) -> boolean,
	Build: (self: Public, gunData: GetGun.GunData) -> (),
}

return {}
