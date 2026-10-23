--!strict

type Slot = {
	Seed: BasePart?,
	NextAt: number,
	PlantedAt: number,
	Last: string?,
}

export type Public = {
	Enabled: boolean,
	Firearms: { string },
	Slots: { [Instance]: Slot },
	Throwables: { string },
	Warned: boolean,
	Setup: (self: Public) -> (),
	BuildPool: (self: Public) -> (),
	Crates: (self: Public) -> { Instance },
	PickGun: (self: Public, last: string?) -> string,
	Plant: (self: Public, crate: Instance, slot: Slot) -> (),
	Step: (self: Public) -> (),
	Clear: (self: Public) -> (),
	Refresh: (self: Public) -> (),
}

return {}
