--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScopeCharacters = require(StarterPlayer.StarterPlayerScripts.client.Weapon.ScopeCharacters)
local ScopeLens = require(StarterPlayer.StarterPlayerScripts.client.Weapon.ScopeLens)
local ScopeView = require(StarterPlayer.StarterPlayerScripts.client.Weapon.ScopeView)
local ScopeViewmodel = require(StarterPlayer.StarterPlayerScripts.client.Weapon.ScopeViewmodel)

export type Public = {
	Active: Vide.Source<boolean>,
	Characters: { ScopeCharacters.ScopeCharacters },
	KickApplied: boolean,
	KickRoll: number,
	KickVelRoll: number,
	KickVelX: number,
	KickVelY: number,
	KickX: number,
	KickY: number,
	Kicking: boolean,
	Lens: ScopeLens.ScopeLens?,
	LensAttached: boolean,
	LensCharacters: ScopeCharacters.ScopeCharacters?,
	MapReady: boolean,
	MirrorOn: boolean,
	Mirrors: { ScopeViewmodel.ScopeViewmodel },
	Model: Model?,
	OverlayAlpha: Vide.Source<number>,
	OverlayCenter: Vide.Source<Vector2>,
	OverlayFraction: Vide.Source<number>,
	OverlayHousing: Vide.Source<Color3>,
	OverlayRotation: Vide.Source<number>,
	PreloadToken: number,
	Raw: number,
	Rendering: boolean,
	Unmount: (() -> ())?,
	View: ScopeView.ScopeView?,
	ViewShown: boolean,
	Setup: (self: Public) -> (),
	Kick: (self: Public, strength: number?) -> (),
	ResetKick: (self: Public) -> (),
	StepKick: (self: Public, deltaTime: number) -> (),
	Fov: (self: Public) -> number?,
	HeldModel: (self: Public) -> Model?,
	ReleaseMap: (self: Public) -> (),
	Preload: (self: Public) -> (),
	SchedulePreload: (self: Public) -> (),
	LensVisibility: (self: Public, alpha: number) -> number,
	ScopeGeometry: (self: Public, alpha: number) -> (number, Vector2),
	Frame: (self: Public, deltaTime: number) -> (),
	StartRendering: (self: Public, model: Model) -> (),
	StopRendering: (self: Public) -> (),
	Sync: (self: Public) -> (),
	Mount: (self: Public, playerGui: PlayerGui) -> (),
}

return {}
