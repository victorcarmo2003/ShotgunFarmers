--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

export type PlayMode = "QuickPlay" | "FFA" | "TDM" | "Practice"
export type State = "Idle" | "Searching" | "Teleporting" | "Failed"
export type RoomMode = "FFA" | "TDM" | "Chicken"
export type Room = { Key: string, Map: string, Mode: string, Players: number, MaxPlayers: number }

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

	CreateRoom = Lync.query(
		Lync.struct({
			Mode = Lync.enum({ "FFA", "TDM", "Chicken" }),
			Map = Lync.str(0, 32),
			Private = Lync.bool(),
		}),
		Lync.struct({
			Accepted = Lync.bool(),
			Reason = Lync.str(0, 200),
		})
	),

	JoinRoom = Lync.query(
		Lync.struct({
			Code = Lync.str(0, 8),
		}),
		Lync.struct({
			Accepted = Lync.bool(),
			Reason = Lync.str(0, 200),
		})
	),

	JoinMatch = Lync.query(
		Lync.struct({
			Key = Lync.str(0, 64),
		}),
		Lync.struct({
			Accepted = Lync.bool(),
			Reason = Lync.str(0, 200),
		})
	),

	ListRooms = Lync.query(
		Lync.empty(),
		Lync.struct({
			Rooms = Lync.array(
				Lync.struct({
					Key = Lync.str(0, 64),
					Map = Lync.str(0, 32),
					Mode = Lync.str(0, 16),
					Players = Lync.int(0, 255),
					MaxPlayers = Lync.int(0, 255),
				}),
				0,
				30
			),
		})
	),

	Cancel = Lync.packet(Lync.empty()),

	ReturnToLobby = Lync.packet(Lync.empty()),
})
