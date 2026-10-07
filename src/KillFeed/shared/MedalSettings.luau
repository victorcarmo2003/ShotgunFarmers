--!strict
const MedalSettings = {
	MultiKillWindow = 4,
	StreakMin = 3,
	MaxMulti = 20,
	MaxStreak = 255,
	RampageMulti = 5,

	MultiTexts = {
		[2] = "DOUBLE KILL",
		[3] = "TRIPLE KILL",
		[4] = "QUAD KILL",
	} :: { [number]: string },
	RampageText = "RAMPAGE",
	HeadshotText = "HEADSHOT",
	StreakFormat = "%d KILL STREAK",

	KillSound = "KillSplat",
	HeadshotSound = "HeadshotSplat",
	MultiSound = "MultiKill",

	HeadshotColor = Color3.fromRGB(255, 210, 60),
	MultiColor = Color3.fromRGB(255, 90, 70),
	RampageColor = Color3.fromRGB(255, 50, 120),
	StreakColor = Color3.fromRGB(255, 255, 255),

	DisplayOrder = 15,
	PositionY = 0.62,
	TextSize = 56,
	SubTextSize = 26,
	StartScale = 1.4,
	PopTime = 0.18,
	Duration = 1.2,
	FadeTime = 0.3,
}

return MedalSettings
