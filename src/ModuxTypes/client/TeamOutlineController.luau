--!strict

export type Public = {
	Connections: { [Player]: { RBXScriptConnection } },
	Setup: (self: Public) -> (),
	Apply: (self: Public, model: Model, team: any) -> (),
	ApplyPlayer: (self: Public, player: Player) -> (),
	ApplyBot: (self: Public, gameId: number, built: Model?) -> (),
	Refresh: (self: Public) -> (),
	Watch: (self: Public, player: Player) -> (),
	Forget: (self: Public, player: Player) -> (),
}

return {}
