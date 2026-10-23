--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BotNet = require(ReplicatedStorage.shared.Bot.Net)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

type Member = BotNet.Member
export type Sample = {
	Time: number,
	Position: Vector3,
	LookAt: Vector3,
	State: BotNet.BotState,
	MoveDir: Vector2,
	WeaponID: number,
}
export type View = {
	GameID: number,
	Buffer: { Sample },
	Model: Model?,
	Root: BasePart?,
	Animator: Animator?,
	Tracks: { [string]: AnimationTrack },
	Playing: string?,
	Hold: AnimationTrack?,
	WeaponID: number,
	Weapon: Model?,
	Dead: boolean,
	Fresh: boolean,
	Rebuild: boolean,
}

export type Public = {
	ByUserId: { [number]: number },
	Changed: SignalLib.Signal<number>,
	Folder: Folder,
	Members: { [number]: Member },
	ModelAdded: SignalLib.Signal<number, Model>,
	Thumbnails: { [number]: string },
	Views: { [number]: View },
	Setup: (self: Public) -> (),
	Find: (self: Public, gameId: number) -> Member?,
	FindByUserId: (self: Public, userId: number) -> (number?, Member?),
	ModelOf: (self: Public, gameId: number) -> Model?,
	Thumbnail: (self: Public, member: Member) -> string,
	SetMember: (self: Public, gameId: number, record: Member) -> (),
	RemoveMember: (self: Public, gameId: number) -> (),
	ViewOf: (self: Public, gameId: number) -> View,
	ClearModel: (self: Public, gameId: number) -> (),
	Push: (self: Public, packet: BotNet.Frames) -> (),
	LoadTracks: (self: Public, view: View, gunName: string?) -> (),
	AttachWeapon: (self: Public, view: View, weaponId: number) -> (),
	Template: (self: Public, gameId: number) -> Instance?,
	BuildModel: (self: Public, view: View) -> boolean,
	Collapse: (self: Public, view: View) -> (),
	Animate: (self: Public, view: View, current: Sample) -> (),
	Render: (self: Public, dt: number) -> (),
}

return {}
