--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	Online: Vide.Source<number>,
	Setup: (self: Public) -> (),
}

return {}
