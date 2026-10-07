--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	Color: Vide.Source<Color3>,
	Connection: RBXScriptConnection?,
	Elapsed: Vide.Source<number>,
	SubText: Vide.Source<string>,
	Text: Vide.Source<string>,
	Unmount: (() -> ())?,
	Setup: (self: Public) -> (),
	Stop: (self: Public) -> (),
	Run: (self: Public) -> (),
	PlaySound: (self: Public, headshot: boolean, multi: number) -> (),
	Show: (self: Public, headshot: boolean, multi: number, streak: number) -> (),
	Mount: (self: Public) -> (),
}

return {}
