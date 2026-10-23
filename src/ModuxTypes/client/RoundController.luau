--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RoundNet = require(ReplicatedStorage.shared.Round.Net)
local Vide = require(ReplicatedStorage.Packages.Vide)
local MatchSummary = require(StarterPlayer.StarterPlayerScripts.client.Round.MatchSummary)

export type Status = RoundNet.Status

export type Public = {
	Gray: number,
	Seconds: Vide.Source<number>,
	Status: Vide.Source<Status>,
	Summary: Vide.Source<MatchSummary.Summary>,
	SummaryToken: number,
	SummaryVisible: Vide.Source<boolean>,
	Setup: (self: Public) -> (),
	ShowSummary: (self: Public, summary: MatchSummary.Summary) -> (),
	HideSummary: (self: Public) -> (),
	MountSummary: (self: Public) -> (),
	Label: (self: Public) -> string,
	Clock: (self: Public) -> string,
	TargetGray: (self: Public) -> number,
	StepGray: (self: Public, deltaTime: number) -> (),
}

return {}
