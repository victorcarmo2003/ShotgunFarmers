--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)

export type Public = {
	Instance: Instance,
	Consumable: boolean,
	GunData: GetGun.GunData?,
	GunName: string,
	Harvested: boolean,
	PlantedAt: number,
	PlanterId: number,
	Prompt: ProximityPrompt?,
	Source: string,
	Trigger: RBXScriptConnection?,
	Setup: (self: Public) -> (),
	Collect: (self: Public, player: Player) -> (boolean, boolean),
	Report: (self: Public, event: "Planted" | "Harvestable" | "Expired") -> (),
	Build: (self: Public, actionText: string, objectText: string) -> (),
}

return {}
