--!strict
return {
	Gems = 0,

	Gamepasses = {} :: { [string]: boolean },

	Item = {} :: { [string]: number },
	UnlockedItems = {} :: { [number]: boolean },
	UnlockedClasses = { [1] = true } :: { [number]: boolean },
	Badgets = {} :: { [number]: boolean },

	FirstLogin = true,

	Wins = 0,
	DayCount = 0,
	CurrentZone = "",
	CurrentClass = "Tank",

	TimeSpent = 0,
	RobuxSpent = 0,
	GemsSpent = 0,
	ChestOpen = 0,
	SpinWheel = 0,

	MusicVolume = 1,
	SoundVolume = 1,
	MusicEnabled = true,
	SoundEnabled = true,
}
