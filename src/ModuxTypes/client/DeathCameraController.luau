--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local DeathScreen = require(StarterPlayer.StarterPlayerScripts.client.Vital.DeathScreen)

export type Public = {
	Dead: Vide.Source<boolean>,
	DeathInfo: Vide.Source<DeathScreen.Info>,
	DeathToken: number,
	Remaining: Vide.Source<number>,
	Spectating: boolean,
	Setup: (self: Public) -> (),
	ShowDeath: (self: Public) -> (),
	HideDeath: (self: Public) -> (),
	BindHumanoid: (self: Public, character: Model) -> (),
	MountDeathScreen: (self: Public) -> (),
	GetSpectateCFrame: (self: Public, shooterRoot: BasePart) -> CFrame,
	StopSpectating: (self: Public) -> (),
	StartSpectating: (self: Public, shooter: Player) -> (),
}

return {}
