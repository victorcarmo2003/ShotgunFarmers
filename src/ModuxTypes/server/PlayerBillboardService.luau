--!strict

export type Public = {
	Template: BillboardGui?,
	Setup: (self: Public) -> (),
	Attach: (self: Public, player: Player, character: Model) -> (),
}

return {}
