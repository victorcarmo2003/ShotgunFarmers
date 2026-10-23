--!strict

type Counter = {
	Name: string,
	Fields: { string },
	Value: number,
}

export type Public = {
	Counts: { [Player]: { [string]: Counter } },
	Kills: { [Player]: number },
	Owned: { [Player]: { [string]: boolean } },
	Started: { [Player]: boolean },
	Setup: (self: Public) -> (),
	Enabled: (self: Public) -> boolean,
	Step: (self: Public, player: Player, step: string, fields: { string }?) -> (),
	Count: (self: Public, player: Player, name: string, fields: { string }) -> (),
	Flush: (self: Public, player: Player) -> (),
	Planter: (self: Public, planterId: number) -> Player?,
	Respawned: (self: Public, player: Player, starting: string?) -> (),
	Planted: (self: Public, gunName: string, source: string, planterId: number) -> (),
	Harvestable: (self: Public, _gunName: string, source: string, planterId: number) -> (),
	Expired: (self: Public, gunName: string, source: string, planterId: number) -> (),
	Harvested: (self: Public, player: Player, gunName: string, source: string, planterId: number, granted: boolean) -> (),
	OnKill: (self: Public, killer: any) -> (),
	Forget: (self: Public, player: Player) -> (),
}

return {}
