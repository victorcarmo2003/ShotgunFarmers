--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

const COUNT_MAX = 4294967295

return Lync.define("Career", {
	Data = Lync.packet(Lync.struct({
		Level = Lync.int(1, 65535),
		Xp = Lync.f64(),
		XpMax = Lync.f64(),
		Wins = Lync.int(0, COUNT_MAX),
		Kills = Lync.int(0, COUNT_MAX),
		Deaths = Lync.int(0, COUNT_MAX),
		Assists = Lync.int(0, COUNT_MAX),
		Headshots = Lync.int(0, COUNT_MAX),
		Matches = Lync.int(0, COUNT_MAX),
		QuestsDone = Lync.int(0, COUNT_MAX),
		Damage = Lync.int(0, COUNT_MAX),
	})),

	Summary = Lync.packet(Lync.struct({
		Outcome = Lync.enum({ "Victory", "Defeat", "Draw" }),
		Placement = Lync.int(0, 255),
		Players = Lync.int(0, 255),
		Kills = Lync.int(0, 65535),
		Deaths = Lync.int(0, 65535),
		Assists = Lync.int(0, 65535),
		Score = Lync.f64(),
		XpGained = Lync.int(0, COUNT_MAX),
		GemsGained = Lync.int(0, COUNT_MAX),
		Level = Lync.int(1, 65535),
		LevelsGained = Lync.int(0, 65535),
		Xp = Lync.f64(),
		XpMax = Lync.f64(),
		Counted = Lync.bool(),
	})),
})
