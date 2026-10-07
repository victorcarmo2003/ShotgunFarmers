--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local StatsNet = require(ReplicatedStorage.shared.Stats.Net)
local Vide = require(ReplicatedStorage.Packages.Vide)
local LeaderstatsScreen = require(StarterPlayer.StarterPlayerScripts.client.Leaderstats.LeaderstatsScreen)

export type Record = {
	Kills: number,
	Deaths: number,
	Assists: number,
	Headshots: number,
	Score: number,
	Ping: number,
	Team: StatsNet.Team,
}

export type Public = {
	Blue: Vide.Source<{ LeaderstatsScreen.Row }>,
	Held: Vide.Source<boolean>,
	Loading: { [number]: boolean },
	Mode: Vide.Source<LeaderstatsScreen.Mode>,
	Records: { [number]: Record },
	Red: Vide.Source<{ LeaderstatsScreen.Row }>,
	Rows: Vide.Source<{ LeaderstatsScreen.Row }>,
	Thumbnails: { [number]: string },
	Totals: Vide.Source<{ Red: number, Blue: number }>,
	Unmount: (() -> ())?,
	Setup: (self: Public) -> (),
	LoadThumbnail: (self: Public, player: Player) -> (),
	Refresh: (self: Public) -> (),
	ApplyMode: (self: Public) -> (),
	IsShown: (self: Public) -> boolean,
	BindKeys: (self: Public) -> (),
	Mount: (self: Public) -> (),
	DisableCorePlayerList: (self: Public) -> (),
}

return {}
