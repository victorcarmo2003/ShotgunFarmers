--!strict

export type Public = {
	RevivedAt: { [Player]: number },
	Setup: (self: Public) -> (),
	Enabled: (self: Public) -> boolean,
	Step: (self: Public, player: Player, step: string, fields: { string }?) -> (),
	Drop: (self: Public, player: Player, reason: string) -> (),
	OnDied: (self: Public, player: Player) -> (),
	OnRevived: (self: Public, player: Player) -> (),
	OnKill: (self: Public, killer: any) -> (),
	OnSpawned: (self: Public, player: Player) -> (),
	OnPromptFinished: (self: Public, userId: number, productId: number, purchased: boolean) -> (),
}

return {}
