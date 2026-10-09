--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local DamageIndicator = require(StarterPlayer.StarterPlayerScripts.client.Vital.DamageIndicator)

type Snapshot = { Health: number, Armor: number, Stamina: number }
type DamageEntry = { From: Vector3, At: number }

export type Public = {
	Armor: Vide.Source<number>,
	DamageEntries: { DamageEntry },
	Flash: Vide.Source<number>,
	Health: Vide.Source<number>,
	Hits: Vide.Source<{ DamageIndicator.Hit }>,
	LowHealth: Vide.Source<number>,
	ResetEvent: BindableEvent,
	Stamina: Vide.Source<number>,
	Setup: (self: Public) -> (),
	OnDamaged: (self: Public, from: Vector3, amount: number) -> (),
	StepIndicators: (self: Public, deltaTime: number) -> (),
	MountIndicators: (self: Public) -> (),
	Apply: (self: Public, snapshot: Snapshot) -> (),
	Of: (self: Public, player: Player) -> Snapshot?,
	BindReset: (self: Public) -> (),
}

return {}
