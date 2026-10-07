--!strict

export type Public = {
	Button: TextButton,
	Forced: boolean,
	Gui: ScreenGui,
	Manual: boolean,
	Menu: boolean,
	Setup: (self: Public) -> (),
	SetUnlocked: (self: Public, unlocked: boolean) -> (),
	Refresh: (self: Public) -> (),
	SetMenu: (self: Public, open: boolean) -> (),
}

return {}
