--!strict

export type Public = {
	Active: boolean,
	Attempts: { [Player]: number },
	Routing: { [Player]: boolean },
	Setup: (self: Public) -> (),
	ReadJoinKeys: (self: Public, player: Player) -> { string },
	CanEnter: (self: Public, player: Player, key: string, owner: number?) -> boolean,
	ResolveExisting: (self: Public, player: Player) -> (string?, string?),
	TryRoute: (self: Public, player: Player) -> (boolean, string?),
	Route: (self: Public, player: Player) -> (),
	RouteAsync: (self: Public, player: Player) -> (),
	Activate: (self: Public) -> (),
}

return {}
