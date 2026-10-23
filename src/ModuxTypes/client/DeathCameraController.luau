--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local DeathScreen = require(StarterPlayer.StarterPlayerScripts.client.Vital.DeathScreen)

export type Public = {
	Dead: Vide.Source<boolean>,
	DeathInfo: Vide.Source<DeathScreen.Info>,
	DeathToken: number,
	FocusDone: boolean,
	Killer: (() -> Model?)?,
	Remaining: Vide.Source<number>,
	RevivalTokens: Vide.Source<number>,
	Spectating: boolean,
	Setup: (self: Public) -> (),
	ReviveText: (self: Public) -> string,
	TryRevive: (self: Public) -> (),
	BindRevive: (self: Public) -> (),
	ShowDeath: (self: Public) -> (),
	HideDeath: (self: Public) -> (),
	BindHumanoid: (self: Public, character: Model) -> (),
	MountDeathScreen: (self: Public) -> (),
	GetSpectateCFrame: (self: Public, shooterRoot: BasePart) -> CFrame,
	Bind: (self: Public, step: (camera: Camera, deltaTime: number) -> ()) -> (),
	FocusSelf: (self: Public) -> (),
	StopSpectating: (self: Public, character: Model?) -> (),
	StartSpectating: (self: Public, shooter: () -> Model?) -> (),
}

return {}
