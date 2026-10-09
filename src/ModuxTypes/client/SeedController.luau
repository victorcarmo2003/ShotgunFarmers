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
	Stages: { Model }?,
	StageScale: number,
}
export type Timer = { Gui: BillboardGui, Anchor: Attachment, Label: TextLabel, Expires: number, Shown: number }

export type Public = {
	Active: { [BasePart]: SeedState },
	Finished: { [BasePart]: boolean },
	Timers: { [BasePart]: Timer },
	Setup: (self: Public) -> (),
	Forget: (self: Public, dirt: BasePart) -> (),
	StartTimer: (self: Public, dirt: BasePart, plant: Model) -> (),
	StepTimers: (self: Public, now: number) -> (),
	Render: (self: Public, dirt: BasePart) -> (),
	TargetGrowth: (self: Public, state: SeedState) -> number,
	AdvanceStage: (self: Public, state: SeedState, stage: number, parent: Instance) -> (),
	ApplyGrowth: (self: Public, state: SeedState) -> (),
	StepSpring: (self: Public, state: SeedState) -> boolean,
	Step: (self: Public) -> (),
}

return {}
