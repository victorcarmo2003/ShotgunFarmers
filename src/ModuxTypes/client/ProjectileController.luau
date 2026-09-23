--!strict

export type Bullet = {
	Part: BasePart,
	StartPos: Vector3,
	EndPos: Vector3,
	StartTime: number,
	ArrivedAt: number?,
}

export type Public = {
	AllBullets: { Bullet },
	Setup: (self: Public) -> (),
	Shoot: (self: Public, startPos: Vector3, endPos: Vector3) -> (),
	Step: (self: Public) -> (),
}

return {}
