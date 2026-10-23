--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

type Entry = {
	Amount: Vide.Source<number>,
	Headshot: Vide.Source<boolean>,
	Killed: Vide.Source<boolean>,
	Pop: Vide.Source<number>,
	Fading: Vide.Source<boolean>,
	Attachment: Attachment,
	Unmount: () -> (),
	LastAt: number,
	Token: number,
}
export type Dealt = {
	TargetID: number,
	Position: Vector3,
	Amount: number,
	Headshot: boolean,
	Killed: boolean,
}

export type Public = {
	Entries: { [number]: Entry },
	Setup: (self: Public) -> (),
	Mount: (self: Public, entry: Entry) -> (),
	Create: (self: Public, data: Dealt) -> Entry,
	Expire: (self: Public, targetID: number, entry: Entry) -> (),
	Schedule: (self: Public, targetID: number, entry: Entry) -> (),
	Show: (self: Public, data: Dealt) -> (),
}

return {}
