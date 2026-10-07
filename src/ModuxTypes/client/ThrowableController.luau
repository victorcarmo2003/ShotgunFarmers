--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ThrowSim = require(ReplicatedStorage.shared.Weapon.ThrowSim)
local Throwables = require(ReplicatedStorage.shared.Weapon.Throwables)
local WeaponNet = require(ReplicatedStorage.shared.Weapon.Net)

export type Flight = {
	Id: number,
	Definition: Throwables.Definition,
	Owner: Player?,
	State: ThrowSim.State,
	Params: RaycastParams,
	Visual: Model,
	VisualOffset: Vector3,
	SpinAge: number,
	ExpiresAt: number,
}
export type Button = "Left" | "Right"
export type GasCloud = {
	Spec: Throwables.ZoneSpec,
	Center: Vector3,
	EndsAt: number,
}

export type Public = {
	Accumulator: number,
	AimParams: RaycastParams,
	Armed: boolean,
	BlindLinger: number,
	BlindUntil: number,
	Blur: BlurEffect,
	Consumed: boolean,
	Flights: { [number]: Flight },
	GasClouds: { GasCloud },
	LastThrow: number,
	Left: boolean,
	PendingMode: number,
	PendingStart: Vector3?,
	PreviewActive: number,
	PreviewDots: { BasePart },
	PreviewFolder: Folder?,
	PreviewMarker: BasePart?,
	PreviewParams: RaycastParams,
	PreviewVisible: boolean,
	Queued: boolean,
	Right: boolean,
	SplitAt: number?,
	Tint: ColorCorrectionEffect,
	Setup: (self: Public) -> (),
	IsThrowableEquipped: (self: Public) -> boolean,
	Begin: (self: Public) -> boolean,
	CanUseInput: (self: Public) -> boolean,
	HeldMode: (self: Public) -> number,
	Press: (self: Public, button: Button) -> boolean,
	ReleaseButton: (self: Public, button: Button) -> (),
	Commit: (self: Public, mode: number) -> (),
	StepStance: (self: Public) -> (),
	PreviewMode: (self: Public) -> number,
	PollAim: (self: Public) -> (),
	ThrowOrigin: (self: Public) -> Vector3?,
	CurrentDefinition: (self: Public) -> Throwables.Definition?,
	AimTarget: (self: Public, camera: Camera, definition: Throwables.Definition?) -> Vector3,
	VisualStart: (self: Public) -> Vector3?,
	Send: (self: Public, start: Vector3?, mode: number) -> boolean,
	Throw: (self: Public) -> (),
	Launch: (self: Public) -> boolean,
	BuildPreview: (self: Public) -> (),
	HidePreview: (self: Public) -> (),
	PreviewDefinition: (self: Public) -> Throwables.Definition?,
	StepPreview: (self: Public) -> (),
	StepQueue: (self: Public) -> (),
	OnSpawn: (self: Public, packet: WeaponNet.ThrowSpawn) -> (),
	Render: (self: Public, flight: Flight) -> (),
	OnDetonate: (self: Public, packet: WeaponNet.ThrowDetonate) -> (),
	ClearAll: (self: Public) -> (),
	StepFlights: (self: Public, deltaTime: number) -> (),
	StepBlind: (self: Public) -> (),
}

return {}
