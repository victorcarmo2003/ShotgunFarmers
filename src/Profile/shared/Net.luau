--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

return Lync.define("Profile", {
	Data = Lync.packet(Lync.struct({
		Gems = Lync.int(0, 4294967295),

		Gamepasses = Lync.map(Lync.str(1, 10), Lync.bool(), 0, 64),

		Item = Lync.map(Lync.str(1, 32), Lync.int(0, 65535), 0, 256),
		UnlockedItems = Lync.map(Lync.int(0, 65535), Lync.bool(), 0, 256),
		UnlockedClasses = Lync.map(Lync.int(0, 65535), Lync.bool(), 0, 64),
		Badgets = Lync.map(Lync.int(0, 65535), Lync.bool(), 0, 64),

		FirstLogin = Lync.bool(),

		Wins = Lync.int(0, 65536),
		DayCount = Lync.int(0, 65536),
		CurrentZone = Lync.str(0, 15),
		CurrentClass = Lync.str(0, 32),

		TimeSpent = Lync.f32(),
		RobuxSpent = Lync.int(0, 1000000),
		GemsSpent = Lync.int(0, 1000000),
		ChestOpen = Lync.int(0, 100000),
		SpinWheel = Lync.int(0, 100000),

		MusicVolume = Lync.quant(0, 1, 0.01),
		SoundVolume = Lync.quant(0, 1, 0.01),
		MusicEnabled = Lync.bool(),
		SoundEnabled = Lync.bool(),
	})),
})
