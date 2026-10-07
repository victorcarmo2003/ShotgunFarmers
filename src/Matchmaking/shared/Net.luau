--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

export type PlayMode = "QuickPlay" | "FFA" | "TDM" | "Practice"
export type State = "Idle" | "Searching" | "Teleporting" | "Failed"

return Lync.define("Matchmaking", {
	Play = Lync.query(
		Lync.struct({
			Mode = Lync.enum({ "QuickPlay", "FFA", "TDM", "Practice" }),
		}),
		Lync.struct({
			Accepted = Lync.bool(),
			Reason = Lync.str(0, 200),
		})
	),

	Status = Lync.packet(Lync.struct({
		State = Lync.enum({ "Idle", "Searching", "Teleporting", "Failed" }),
		Reason = Lync.str(0, 200),
	})),

	Cancel = Lync.packet(Lync.empty()),

	ReturnToLobby = Lync.packet(Lync.empty()),
})
