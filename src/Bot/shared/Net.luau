--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

export type BotState = "Walking" | "Running" | "Crouch" | "Sliding" | "Jumping" | "Dead"

export type Team = "None" | "Red" | "Blue"

export type Member = {
	DisplayName: string,
	UserId: number,
	AvatarId: number,
	Team: Team,
}

export type Frame = {
	GameID: number,
	Position: Vector3,
	LookAt: Vector3,
	State: BotState,
	MoveDir: Vector2,
	WeaponID: number,
}

export type Frames = {
	TimeStamp: number,
	Bots: { Frame },
}

return Lync.define("Bot", {
	Roster = Lync.replicate(Lync.struct({
		DisplayName = Lync.str(0, 32),
		UserId = Lync.f64(),
		AvatarId = Lync.f64(),
		Team = Lync.enum({ "None", "Red", "Blue" }),
	})),

	Frames = Lync.packet(Lync.struct({
		TimeStamp = Lync.f64(),
		Bots = Lync.array(
			Lync.struct({
				GameID = Lync.int(0, 255),
				Position = Lync.vec3(Lync.quant(-4096, 4096, 0.125)),
				LookAt = Lync.vec3(Lync.quant(-4096, 4096, 0.25)),
				State = Lync.enum({ "Walking", "Running", "Crouch", "Sliding", "Jumping", "Dead" }),
				MoveDir = Lync.vec2(Lync.quant(-1, 1, 0.01)),
				WeaponID = Lync.int(0, 255),
			}),
			0,
			32
		),
	})):unreliable() :: any,
})
