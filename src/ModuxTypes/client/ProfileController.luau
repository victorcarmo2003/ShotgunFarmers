--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	Badgets: Vide.Source<{ [number]: boolean }>,
	ChestOpen: Vide.Source<number>,
	CurrentClass: Vide.Source<string>,
	CurrentZone: Vide.Source<string>,
	DayCount: Vide.Source<number>,
	FirstLogin: Vide.Source<boolean>,
	Gamepasses: Vide.Source<{ [string]: boolean }>,
	Gems: Vide.Source<number>,
	GemsSpent: Vide.Source<number>,
	Item: Vide.Source<{ [string]: number }>,
	MusicEnabled: Vide.Source<boolean>,
	MusicVolume: Vide.Source<number>,
	Ready: Vide.Source<boolean>,
	RobuxSpent: Vide.Source<number>,
	SoundEnabled: Vide.Source<boolean>,
	SoundVolume: Vide.Source<number>,
	SpinWheel: Vide.Source<number>,
	TimeSpent: Vide.Source<number>,
	UnlockedClasses: Vide.Source<{ [number]: boolean }>,
	UnlockedItems: Vide.Source<{ [number]: boolean }>,
	Wins: Vide.Source<number>,
	Setup: (self: Public) -> (),
}

return {}
