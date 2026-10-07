--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

export type MemberStatus = "Present" | "Idle" | "Away" | "Joining"
export type Location = "Lobby" | "Match"

export type Member = {
	UserId: number,
	Name: string,
	Slot: number,
	Status: MemberStatus,
}

export type Friend = {
	UserId: number,
	Name: string,
	Location: Location,
	InSquad: boolean,
}

return Lync.define("Party", {
	State = Lync.packet(Lync.struct({
		Leader = Lync.f64(),
		Members = Lync.array(
			Lync.struct({
				UserId = Lync.f64(),
				Name = Lync.str(0, 40),
				Slot = Lync.int(1, 5),
				Status = Lync.enum({ "Present", "Idle", "Away", "Joining" }),
			}),
			0,
			5
		),
	})),

	Friends = Lync.query(
		Lync.struct({
			Candidates = Lync.array(Lync.f64(), 0, 50),
		}),
		Lync.struct({
			Entries = Lync.array(
				Lync.struct({
					UserId = Lync.f64(),
					Name = Lync.str(0, 40),
					Location = Lync.enum({ "Lobby", "Match" }),
					InSquad = Lync.bool(),
				}),
				0,
				50
			),
		})
	),

	Invite = Lync.query(
		Lync.struct({
			UserId = Lync.f64(),
		}),
		Lync.struct({
			Accepted = Lync.bool(),
			Reason = Lync.str(0, 200),
		})
	),

	Invited = Lync.packet(Lync.struct({
		Id = Lync.str(1, 64),
		From = Lync.f64(),
		FromName = Lync.str(0, 40),
		Seconds = Lync.int(0, 120),
	})),

	Respond = Lync.packet(Lync.struct({
		Id = Lync.str(1, 64),
		Accept = Lync.bool(),
	})),

	Resolved = Lync.packet(Lync.struct({
		UserId = Lync.f64(),
	})),

	Notice = Lync.packet(Lync.struct({
		Message = Lync.str(0, 200),
	})),
})
