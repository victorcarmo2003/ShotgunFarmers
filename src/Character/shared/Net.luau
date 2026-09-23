--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

export type MovementState = "Walking" | "Running" | "Crouch" | "Sliding" | "Jumping" | "Dead"
export type MovementAction = "Walk" | "Sprint" | "Crouch" | "Slide" | "Jump"

return Lync.define("Character", {
	Movement = Lync.replicate(Lync.struct({
		State = Lync.enum({ "Walking", "Running", "Crouch", "Sliding", "Jumping", "Dead" }),
		WalkSpeed = Lync.int(0, 48),
	})),

	ChangeMovement = Lync.query(
		Lync.struct({ Action = Lync.enum({ "Walk", "Sprint", "Crouch", "Slide", "Jump" }) }),
		Lync.struct({ CanDo = Lync.bool() })
	),
})
