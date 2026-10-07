--!strict

export type Public = {
	Reconcile: (self: Public, player: Player) -> (),
	ReconcileAll: (self: Public) -> (),
}

return {}
