--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

type Snapshot = { Health: number, Armor: number, Stamina: number }

export type Public = {
	Armor: Vide.Source<number>,
	Health: Vide.Source<number>,
	Stamina: Vide.Source<number>,
	Setup: (self: Public) -> (),
	Apply: (self: Public, snapshot: Snapshot) -> (),
	Of: (self: Public, player: Player) -> Snapshot?,
}

return {}
