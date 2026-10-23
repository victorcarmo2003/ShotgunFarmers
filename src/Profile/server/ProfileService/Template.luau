--!strict
return {
	Gems = 0,

	Gamepasses = {} :: { [string]: boolean },
	PurchaseIds = {} :: { string },
	RevivalTokens = 0,
	XpBoostEnds = 0,
	CropDrops = 0,

	RedeemedCodes = {} :: { [string]: boolean },
	OwnedSkins = {} :: { [string]: boolean },
	EquippedSkins = {} :: { [string]: string },

	Item = {} :: { [string]: number },
	UnlockedItems = {} :: { [number]: boolean },
	UnlockedClasses = { [1] = true } :: { [number]: boolean },
	Badgets = {} :: { [number]: boolean },

	FirstLogin = true,

	Wins = 0,
	Xp = 0,
	Level = 1,
	Career = {
		Kills = 0,
		Deaths = 0,
		Assists = 0,
		Headshots = 0,
		Matches = 0,
		QuestsDone = 0,
		Damage = 0,
	},
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

	Settings = {} :: { [string]: number },
	Keybinds = {} :: { [string]: string },
}
