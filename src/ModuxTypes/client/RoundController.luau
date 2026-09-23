--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoundNet = require(ReplicatedStorage.shared.Round.Net)
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Status = RoundNet.Status

export type Public = {
	Seconds: Vide.Source<number>,
	Status: Vide.Source<Status>,
	Setup: (self: Public) -> (),
	Label: (self: Public) -> string,
}

return {}
