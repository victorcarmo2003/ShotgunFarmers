--!strict

export type Public = {
	Button: TextButton,
	Gui: ScreenGui,
	Setup: (self: Public) -> (),
	SetUnlocked: (self: Public, unlocked: boolean) -> (),
}

return {}
