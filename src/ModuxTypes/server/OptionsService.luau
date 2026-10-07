--!strict

export type Public = {
	Windows: { [Player]: { Start: number, Count: number } },
	Setup: (self: Public) -> (),
	Allow: (self: Public, player: Player) -> boolean,
	SendState: (self: Public, player: Player) -> (),
	SetSetting: (self: Public, player: Player, id: string, value: number) -> (),
	SetKeybind: (self: Public, player: Player, id: string, key: string) -> (),
}

return {}
