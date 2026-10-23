--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local OptionsCatalog = require(ReplicatedStorage.shared.Options.OptionsCatalog)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Crosshair = require(StarterPlayer.StarterPlayerScripts.client.Weapon.Crosshair)
local OptionsScreen = require(StarterPlayer.StarterPlayerScripts.client.Options.OptionsScreen)

export type Public = {
	CaptureConnection: RBXScriptConnection?,
	CaptureGuard: boolean,
	Capturing: Vide.Source<string?>,
	Dirty: { [string]: number },
	Keys: Vide.Source<{ [string]: string }>,
	Opened: Vide.Source<boolean>,
	Tokens: { [string]: number },
	Unmount: (() -> ())?,
	Values: Vide.Source<{ [string]: number }>,
	Setup: (self: Public) -> (),
	Get: (self: Public, id: string) -> number,
	Fraction: (self: Public, slider: OptionsCatalog.Slider) -> number,
	ChoiceIndex: (self: Public, choice: OptionsCatalog.Choice) -> number,
	ToggleCrouch: (self: Public) -> boolean,
	KeyName: (self: Public, id: string) -> string,
	SetLocal: (self: Public, id: string, value: number) -> (),
	Flush: (self: Public, id: string) -> (),
	FlushAll: (self: Public) -> (),
	Queue: (self: Public, id: string, value: number) -> (),
	SetSlider: (self: Public, id: string, fraction: number) -> (),
	StepChoice: (self: Public, id: string, direction: number) -> (),
	ApplyKeys: (self: Public) -> (),
	SendKey: (self: Public, id: string, name: string) -> (),
	Assign: (self: Public, id: string, name: string) -> (),
	Clear: (self: Public, id: string) -> (),
	EndCapture: (self: Public) -> (),
	BeginCapture: (self: Public, id: string) -> (),
	SetOpen: (self: Public, open: boolean) -> (),
	Toggle: (self: Public) -> (),
	SliderRows: (self: Public, list: { OptionsCatalog.Slider }) -> { OptionsScreen.Slider },
	CrosshairConfig: (self: Public) -> Crosshair.Config,
	ApplyPreset: (self: Public, presetId: string) -> (),
	CrosshairRow: (self: Public, entry: OptionsCatalog.CrosshairEntry) -> OptionsScreen.CrosshairRow?,
	CrosshairSections: (self: Public) -> { OptionsScreen.CrosshairSection },
	Mount: (self: Public) -> (),
}

return {}
