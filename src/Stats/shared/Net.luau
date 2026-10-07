--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

export type Team = "None" | "Red" | "Blue"

return Lync.define("Stats", {
	Rows = Lync.replicate(Lync.struct({
		Kills = Lync.int(0, 65535),
		Deaths = Lync.int(0, 65535),
		Assists = Lync.int(0, 65535),
		Headshots = Lync.int(0, 65535),
		Score = Lync.int(0, 1000000),
		Ping = Lync.int(0, 9999),
		Team = Lync.enum({ "None", "Red", "Blue" }),
	})),

	Totals = Lync.packet(Lync.struct({
		Red = Lync.int(0, 1000000),
		Blue = Lync.int(0, 1000000),
	})),
})
