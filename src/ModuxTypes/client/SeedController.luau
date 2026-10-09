--!strict

export type SeedState = {
	SeedInstance: Model,
	PlantedAt: number,
	StartDirtSize: Vector3,
	EndDirtSize: Vector3,
	StartCFrame: CFrame,
	EndCFrame: CFrame,
	Stage: number,
	Growth: number,
	Velocity: number,
}

export type Public = {
	Active: { [BasePart]: SeedState },
	Finished: { [BasePart]: boolean },
	Setup: (self: Public) -> (),
	Forget: (self: Public, dirt: BasePart) -> (),
	Render: (self: Public, dirt: BasePart) -> (),
	ApplyGrowth: (self: Public, state: SeedState) -> (),
	StepSpring: (self: Public, state: SeedState) -> boolean,
	Step: (self: Public) -> (),
}

return {}
