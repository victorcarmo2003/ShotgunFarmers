--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

export type Status = "Starting" | "Match" | "Intermission" | "Vote"

return Lync.define("Round", {
	State = Lync.packet(Lync.struct({
		Status = Lync.enum({ "Starting", "Match", "Intermission", "Vote" }),
		Seconds = Lync.int(0, 3600),
	})),
})
