--!strict

export type Public = {
	Instance: Instance,
	Alive: boolean,
	Armor: number,
	Health: number,
	Owner: Player,
	Stamina: number,
	Setup: (self: Public) -> (),
	Publish: (self: Public) -> (),
	TakeDamage: (self: Public, amount: number) -> boolean,
	NotifyRestored: (self: Public, before: number) -> (),
	Heal: (self: Public, amount: number) -> (),
	SetArmor: (self: Public, amount: number) -> (),
	SpendStamina: (self: Public, amount: number) -> boolean,
	Revive: (self: Public) -> (),
}

return {}
