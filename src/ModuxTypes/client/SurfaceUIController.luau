--!strict

export type PanelConfig = {
	Depth: number?,
	Rotation: Vector3?,
}
type EffectState = { Trauma: number, Seed: number }
type Panel = { Part: Part, Offset: CFrame }

export type Public = {
	Effects: { [Part]: { [string]: EffectState } },
	Panels: { [string]: Panel },
	Setup: (self: Public) -> (),
	New: (self: Public, name: string, config: PanelConfig?) -> Part?,
	Get: (self: Public, name: string) -> Part?,
	Remove: (self: Public, name: string) -> (),
	Shake: (self: Public, part: Part, intensity: number) -> (),
	ShakeAll: (self: Public, intensity: number) -> (),
}

return {}
