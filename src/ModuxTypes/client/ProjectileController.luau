--!strict

export type Bullet = {
	Part: BasePart,
	Template: string,
	StartPos: Vector3,
	EndPos: Vector3,
	Control: Vector3?,
	StartTime: number,
	Speed: number,
	Linger: number,
	ArrivedAt: number?,
}
export type TracerPool = { Free: { BasePart }, Count: number, Linger: number }
export type Streak = { Beam: Beam, Start: Attachment, Finish: Attachment, CreatedAt: number }

export type Public = {
	AllBullets: { Bullet },
	Pools: { [string]: TracerPool },
	Streaks: { Streak },
	Setup: (self: Public) -> (),
	Acquire: (self: Public, name: string) -> (BasePart?, number),
	Release: (self: Public, bullet: Bullet) -> (),
	Shoot: (self: Public, startPos: Vector3, endPos: Vector3, tracer: string?, speed: number?, control: Vector3?) -> (),
	Streak: (self: Public, startPos: Vector3, endPos: Vector3, control: Vector3?) -> (),
	StepStreaks: (self: Public, now: number) -> (),
	Flame: (self: Public, origin: Vector3, direction: Vector3, range: number, spread: number) -> (),
	Step: (self: Public) -> (),
}

return {}
