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
})
