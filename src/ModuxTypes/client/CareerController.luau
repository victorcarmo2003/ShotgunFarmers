--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local CareerScreen = require(StarterPlayer.StarterPlayerScripts.client.Career.CareerScreen)

export type Public = {
	Level: Vide.Source<number>,
	Stats: Vide.Source<{ CareerScreen.Stat }>,
	Xp: Vide.Source<number>,
	XpMax: Vide.Source<number>,
	Setup: (self: Public) -> (),
}

return {}
