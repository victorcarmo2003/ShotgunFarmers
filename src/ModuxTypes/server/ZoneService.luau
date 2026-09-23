--!strict

export type Public = {
	Zones: { [Player]: string },
	Setup: (self: Public) -> (),
	Publish: (self: Public, player: Player, zone: string) -> (),
	Enter: (self: Public, player: Player, zone: string) -> (),
	Leave: (self: Public, player: Player, zone: string) -> (),
}

return {}
