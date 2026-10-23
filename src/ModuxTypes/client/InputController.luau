--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameState = require(ReplicatedStorage.shared.Match.GameState)
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Context = "Gameplay" | "Menu"
export type TouchMenu = {
	Text: string,
	Color: Color3,
	Order: number,
	Toggle: boolean?,
	Visible: (() -> boolean)?,
}
export type TouchEntry = {
	Name: string,
	Menu: TouchMenu,
}
export type Binding = {
	Name: string,
	Key: Enum.KeyCode | Enum.UserInputType,
	TouchButton: boolean?,
	Touch: TouchMenu?,
	Priority: number?,
	Position: UDim2?,
	Requires: GameState.Capability?,
}
export type Handle = {
	OnPress: (callback: () -> ()) -> Handle,
	OnRelease: (callback: () -> ()) -> Handle,
	Unbind: () -> (),
	Requires: GameState.Capability?,
	_press: { () -> () },
	_release: { () -> () },
}

export type Public = {
	Bindings: { [string]: Binding },
	Context: Context,
	Handles: { [string]: Handle },
	Listeners: { (Context) -> () },
	Overrides: { [string]: Enum.KeyCode },
	TouchMenus: Vide.Source<{ TouchEntry }>,
	Setup: (self: Public) -> (),
	TouchAllowed: (self: Public) -> boolean,
	Dispatch: (self: Public, name: string, state: Enum.UserInputState) -> Enum.ContextActionResult,
	Bind: (self: Public, binding: Binding) -> Handle,
	SetTouchMenu: (self: Public, name: string, menu: TouchMenu?) -> (),
	KeyOf: (self: Public, name: string) -> (Enum.KeyCode | Enum.UserInputType)?,
	Register: (self: Public, name: string) -> (),
	Rebind: (self: Public, name: string, key: Enum.KeyCode?) -> (),
	SetOverrides: (self: Public, overrides: { [string]: Enum.KeyCode }) -> (),
	Unbind: (self: Public, name: string) -> (),
	OnContextChange: (self: Public, callback: (Context) -> ()) -> (),
	SetContext: (self: Public, context: Context) -> (),
}

return {}
