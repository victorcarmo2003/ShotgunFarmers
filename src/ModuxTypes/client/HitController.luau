--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	HitMarkerTrigger: Vide.Source<number>,
	LastShotTime: number,
	Setup: (self: Public) -> (),
	TryHit: (self: Public) -> boolean,
}

return {}
