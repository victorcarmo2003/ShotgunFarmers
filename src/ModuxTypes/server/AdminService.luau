--!strict

export type Public = {
	CommandGive: (self: Public, kind: string, target: Player, value: any) -> (),
	CommandKill: (self: Public, target: Player, reason: string?) -> (),
	CommandWipe: (self: Public, target: Player, rejoin: boolean?) -> (),
	CommandTeleport: (self: Public, a: Player, b: Player?) -> (),
	Register: (self: Public) -> (),
}

return {}
