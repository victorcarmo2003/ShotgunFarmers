--!strict

export type Context = "Gameplay" | "Menu"
export type Binding = {
	Name: string,
	Key: Enum.KeyCode | Enum.UserInputType,
	TouchButton: boolean?,
	Priority: number?,
	Position: UDim2?,
}
export type Handle = {
	OnPress: (callback: () -> ()) -> Handle,
	OnRelease: (callback: () -> ()) -> Handle,
	Unbind: () -> (),
	_press: { () -> () },
	_release: { () -> () },
}

export type Public = {
	Context: Context,
	Handles: { [string]: Handle },
	Listeners: { (Context) -> () },
	Setup: (self: Public) -> (),
	Dispatch: (self: Public, name: string, state: Enum.UserInputState) -> Enum.ContextActionResult,
	Bind: (self: Public, binding: Binding) -> Handle,
	Unbind: (self: Public, name: string) -> (),
	OnContextChange: (self: Public, callback: (Context) -> ()) -> (),
	SetContext: (self: Public, context: Context) -> (),
}

return {}
