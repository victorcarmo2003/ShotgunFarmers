--!strict

export type Bullet = {
	Part: BasePart,
	Template: string,
	StartPos: Vector3,
	EndPos: Vector3,
	StartTime: number,
	Speed: number,
	Linger: number,
	ArrivedAt: number?,
}
export type TracerPool = { Free: { BasePart }, Count: number, Linger: number }

export type Public = {
	AllBullets: { Bullet },
	Pools: { [string]: TracerPool },
	Setup: (self: Public) -> (),
	Acquire: (self: Public, name: string) -> (BasePart?, number),
	Release: (self: Public, bullet: Bullet) -> (),
	Shoot: (self: Public, startPos: Vector3, endPos: Vector3, tracer: string?, speed: number?) -> (),
	Flame: (self: Public, origin: Vector3, direction: Vector3, range: number, spread: number) -> (),
	Step: (self: Public) -> (),
}

return {}
