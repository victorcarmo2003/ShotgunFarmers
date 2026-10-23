--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	Alpha: Vide.Source<number>,
	Message: Vide.Source<string>,
	Token: number,
	Setup: (self: Public) -> (),
	BuySkin: (self: Public, id: string) -> (boolean, string),
	RedeemCode: (self: Public, code: string) -> (boolean, string),
	EquipSkin: (self: Public, id: string, equip: boolean) -> (boolean, string),
	Fade: (self: Public, from: number, to: number, token: number) -> (),
	Show: (self: Public, message: string) -> (),
	Mount: (self: Public) -> (),
}

return {}
