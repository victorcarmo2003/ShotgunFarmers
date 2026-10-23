--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local KillFeed = require(StarterPlayer.StarterPlayerScripts.client.KillFeed.KillFeed)
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Entry = KillFeed.Entry
export type Identity = { Name: string, Image: string }

export type Public = {
	Entries: Vide.Source<{ Entry }>,
	Thumbnails: { [Player]: string },
	Setup: (self: Public) -> (),
	Thumbnail: (self: Public, player: Player) -> string,
	Identify: (self: Public, id: number) -> Identity?,
	Forget: (self: Public, entry: Entry) -> (),
	Push: (self: Public, shooter: Identity, victim: Identity, gunName: string, isHeadshot: boolean) -> (),
}

return {}
