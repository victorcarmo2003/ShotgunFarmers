--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PartyNet = require(ReplicatedStorage.shared.Party.Net)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)

type Invite = {
	Id: string,
	From: number,
	FromName: string,
	Started: number,
	Duration: number,
}

export type Public = {
	Current: Vide.Source<Invite | false>,
	Friends: Vide.Source<{ PartyNet.Friend }>,
	InviteRequested: SignalLib.Signal<>,
	Leader: Vide.Source<number>,
	Loading: Vide.Source<boolean>,
	Members: Vide.Source<{ PartyNet.Member }>,
	Notice: SignalLib.Signal<string>,
	Progress: Vide.Source<number>,
	Queue: { Invite },
	Sent: Vide.Source<{ [number]: boolean }>,
	Timer: RBXScriptConnection?,
	Setup: (self: Public) -> (),
	MemberAt: (self: Public, slot: number) -> PartyNet.Member?,
	IsLeader: (self: Public) -> boolean,
	Candidates: (self: Public) -> { number },
	LoadFriends: (self: Public) -> { PartyNet.Friend },
	MarkSent: (self: Public, userId: number, sent: boolean) -> (),
	Invite: (self: Public, userId: number) -> (boolean, string),
	StopTimer: (self: Public) -> (),
	ShowNext: (self: Public) -> (),
	Respond: (self: Public, accept: boolean) -> (),
	Enqueue: (self: Public, data: { Id: string, From: number, FromName: string, Seconds: number }) -> (),
	MountPopup: (self: Public) -> (),
	SlotPart: (self: Public, slot: number) -> BasePart?,
	Billboard: (self: Public, slot: number, lobbyRoot: () -> Instance | false) -> BillboardGui,
	MountBillboards: (self: Public) -> (),
	BindKeys: (self: Public) -> (),
}

return {}
