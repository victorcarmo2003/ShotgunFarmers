--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

return Lync.define("KillFeed", {
	Kill = Lync.packet(Lync.struct({
		ShooterID = Lync.int(0, 255),
		VictimID = Lync.int(0, 255),
		GunName = Lync.str(0, 20),
		IsHeadshot = Lync.bool(),
	})),
	Medal = Lync.packet(Lync.struct({
		Headshot = Lync.bool(),
		Multi = Lync.int(1, 20),
		Streak = Lync.int(0, 255),
	})),
})
