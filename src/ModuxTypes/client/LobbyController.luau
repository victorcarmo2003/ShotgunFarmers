--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local GameSelectionScreen = require(StarterPlayer.StarterPlayerScripts.client.GameSelection.GameSelectionScreen)

export type Public = {
	Active: boolean,
	CameraChangedConnection: RBXScriptConnection?,
	CameraConnections: { RBXScriptConnection },
	CameraPart: BasePart?,
	CurrentScreen: Vide.Source<string>,
	ErrorShown: boolean,
	Inviting: boolean,
	PopupUnmount: (() -> ())?,
	ScreenUnmount: (() -> ())?,
	Token: number,
	Setup: (self: Public) -> (),
	Open: (self: Public, name: string) -> (),
	Close: (self: Public) -> (),
	Toggle: (self: Public, name: string) -> (),
	UpdateCamera: (self: Public) -> (),
	SelectMode: (self: Public, mode: GameSelectionScreen.Mode) -> (),
	StatusText: (self: Public) -> string,
	JoinRoom: (self: Public) -> (),
	CreateRoom: (self: Public) -> (),
	BuyRobux: (self: Public, id: string) -> (),
	BuyCoins: (self: Public, id: string) -> (),
	RedeemQuest: (self: Public, id: string) -> (),
	Invite: (self: Public) -> (),
	InviteFriend: (self: Public, userId: number) -> (),
	PromptRobloxInvite: (self: Public) -> (),
	MountScreen: (self: Public) -> (),
	DisableControls: (self: Public) -> (),
	ApplyCamera: (self: Public) -> (),
	ClearCameraConnections: (self: Public) -> (),
	BindCamera: (self: Public) -> (),
	FindCameraPart: (self: Public) -> BasePart?,
	EnableControls: (self: Public) -> (),
	EnterLobby: (self: Public) -> (),
	ExitLobby: (self: Public) -> (),
	OnState: (self: Public, state: string) -> (),
	ShowError: (self: Public, message: string, title: string?) -> (),
}

return {}
