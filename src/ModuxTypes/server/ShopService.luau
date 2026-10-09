--!strict

export type Public = {
	Warned: boolean,
	Setup: (self: Public) -> (),
	HasPass: (self: Public, player: Player, id: string) -> boolean,
	GemMultiplier: (self: Public, player: Player) -> number,
	GrantPass: (self: Public, player: Player, id: string) -> (),
	SyncPasses: (self: Public, player: Player) -> (),
	ProcessReceipt: (self: Public, receipt: { [string]: any }) -> Enum.ProductPurchaseDecision,
	WarnMissingIds: (self: Public) -> (),
}

return {}
