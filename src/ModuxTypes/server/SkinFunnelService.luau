--!strict

export type Public = {
	Step: (self: Public, player: Player, step: string, fields: { string }?) -> (),
	OnAttempt: (self: Public, player: Player, id: string, accepted: boolean, reason: string) -> (),
	OnBought: (self: Public, player: Player, id: string, currency: string) -> (),
	OnResolved: (self: Public, player: Player) -> (),
}

return {}
