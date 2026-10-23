--!strict

export type Public = {
	CommandRound: (self: Public, action: string) -> (),
	CommandGive: (self: Public, kind: string, target: Player, value: any) -> (),
	CommandKill: (self: Public, target: Player, reason: string?) -> (),
	CommandTakeDamage: (self: Public, target: Player, amount: number) -> (),
	CommandWipe: (self: Public, target: Player, rejoin: boolean?) -> (),
	CommandTeleport: (self: Public, a: Player, b: Player?) -> (),
	CursorPoint: (self: Public, player: Player) -> Vector3?,
	PlayerPoint: (self: Public, player: Player) -> Vector3?,
	SpawnPoint: (self: Public, mode: string, a: any, b: any, c: any) -> Vector3?,
	CommandSpawn: (self: Public, seed: string, mode: string, a: any, b: any, c: any) -> (),
	Register: (self: Public) -> (),
}

return {}
