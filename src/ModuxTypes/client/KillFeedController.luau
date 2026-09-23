--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local KillFeed = require(StarterPlayer.StarterPlayerScripts.client.KillFeed.KillFeed)
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Entry = KillFeed.Entry

export type Public = {
	Entries: Vide.Source<{ Entry }>,
	Thumbnails: { [Player]: string },
	Setup: (self: Public) -> (),
	Thumbnail: (self: Public, player: Player) -> string,
	Forget: (self: Public, entry: Entry) -> (),
	Push: (self: Public, shooter: Player, victim: Player, gunName: string, isHeadshot: boolean) -> (),
}

return {}
