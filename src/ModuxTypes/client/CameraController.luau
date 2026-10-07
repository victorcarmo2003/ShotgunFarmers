--!strict

export type EffectState = { Trauma: number, Seed: number }

export type Public = {
	CurrentTilt: number,
	Effects: { [string]: EffectState },
	FirstPerson: boolean,
	Setup: (self: Public) -> (),
	GetLookPart: (self: Public) -> (BasePart?, Player?),
	GetLookAt: (self: Public) -> Vector3?,
	GetLookDirection: (self: Public) -> Vector3?,
	CreateEffect: (self: Public, effectName: string, intensity: number) -> (),
	GetTiltOffset: (self: Public, camera: Camera, deltaTime: number) -> CFrame,
	Step: (self: Public, deltaTime: number) -> (),
}

return {}
