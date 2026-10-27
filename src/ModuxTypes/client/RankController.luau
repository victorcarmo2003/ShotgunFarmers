--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local RankSettings = require(ReplicatedStorage.shared.Rank.RankSettings)

type Category = RankSettings.Category
type Entry = RankSettings.Entry

export type Public = {
	Boards: Vide.Source<{ [Category]: { Entry } }>,
	Mine: Vide.Source<{ [Category]: number }>,
	Setup: (self: Public) -> (),
}

return {}
