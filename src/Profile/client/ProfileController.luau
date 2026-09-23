--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const ProfileController = Modux.Controller("ProfileController", { Priority = 800 })

function ProfileController:Setup()
	self.Gems = Vide.source(0) :: Vide.Source<number>

	self.Gamepasses = Vide.source({}) :: Vide.Source<{ [string]: boolean }>
	self.Item = Vide.source({}) :: Vide.Source<{ [string]: number }>
	self.UnlockedItems = Vide.source({}) :: Vide.Source<{ [number]: boolean }>
	self.UnlockedClasses = Vide.source({}) :: Vide.Source<{ [number]: boolean }>
	self.Badgets = Vide.source({}) :: Vide.Source<{ [number]: boolean }>

	self.FirstLogin = Vide.source(true) :: Vide.Source<boolean>

	self.Wins = Vide.source(0) :: Vide.Source<number>
	self.DayCount = Vide.source(0) :: Vide.Source<number>
	self.CurrentZone = Vide.source("") :: Vide.Source<string>
	self.CurrentClass = Vide.source("Tank") :: Vide.Source<string>

	self.TimeSpent = Vide.source(0) :: Vide.Source<number>
	self.RobuxSpent = Vide.source(0) :: Vide.Source<number>
	self.GemsSpent = Vide.source(0) :: Vide.Source<number>
	self.ChestOpen = Vide.source(0) :: Vide.Source<number>
	self.SpinWheel = Vide.source(0) :: Vide.Source<number>

	self.MusicVolume = Vide.source(1) :: Vide.Source<number>
	self.SoundVolume = Vide.source(1) :: Vide.Source<number>
	self.MusicEnabled = Vide.source(true) :: Vide.Source<boolean>
	self.SoundEnabled = Vide.source(true) :: Vide.Source<boolean>

	self.Ready = Vide.source(false) :: Vide.Source<boolean>
end

ProfileController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Profile.Data:onClient(function(data)
		self.Gems(data.Gems)

		self.Gamepasses(data.Gamepasses)
		self.Item(data.Item)
		self.UnlockedItems(data.UnlockedItems)
		self.UnlockedClasses(data.UnlockedClasses)
		self.Badgets(data.Badgets)

		self.FirstLogin(data.FirstLogin)

		self.Wins(data.Wins)
		self.DayCount(data.DayCount)
		self.CurrentZone(data.CurrentZone)
		self.CurrentClass(data.CurrentClass)

		self.TimeSpent(data.TimeSpent)
		self.RobuxSpent(data.RobuxSpent)
		self.GemsSpent(data.GemsSpent)
		self.ChestOpen(data.ChestOpen)
		self.SpinWheel(data.SpinWheel)

		self.MusicVolume(data.MusicVolume)
		self.SoundVolume(data.SoundVolume)
		self.MusicEnabled(data.MusicEnabled)
		self.SoundEnabled(data.SoundEnabled)

		self.Ready(true)
	end)
end)

return ProfileController
