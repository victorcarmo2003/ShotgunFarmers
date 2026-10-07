--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local VoteMenu = require(StarterPlayer.StarterPlayerScripts.client.Round.VoteMenu)

export type Public = {
	HoldToken: number,
	Holding: Vide.Source<boolean>,
	Mode: Vide.Source<string>,
	MyVote: Vide.Source<number>,
	Unmount: (() -> ())?,
	Votes: Vide.Source<{ [number]: number }>,
	Winner: Vide.Source<number>,
	Setup: (self: Public) -> (),
	Entries: (self: Public) -> { VoteMenu.Option },
	SetVotes: (self: Public, index: number, count: number?) -> (),
	Cast: (self: Public, index: number) -> (),
	ShowResult: (self: Public, index: number) -> (),
	IsVisible: (self: Public) -> boolean,
	Mount: (self: Public) -> (),
}

return {}
