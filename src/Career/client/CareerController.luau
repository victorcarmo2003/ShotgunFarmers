--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local CareerScreen = require(StarterPlayer.StarterPlayerScripts.client.Career.CareerScreen)

export type Totals = {
	Level: number,
	Wins: number,
	Kills: number,
	Deaths: number,
	Assists: number,
	Headshots: number,
	Matches: number,
	QuestsDone: number,
	Damage: number,
}

const EMPTY: Totals = {
	Level = 1,
	Wins = 0,
	Kills = 0,
	Deaths = 0,
	Assists = 0,
	Headshots = 0,
	Matches = 0,
	QuestsDone = 0,
	Damage = 0,
}

const CareerController = Modux.Controller("CareerController", { Priority = 390 })

local function buildStats(totals: Totals): { CareerScreen.Stat }
	const ratio = if totals.Deaths > 0 then totals.Kills / totals.Deaths else totals.Kills

	return {
		{ Label = "WINS", Value = totals.Wins },
		{ Label = "KILLS", Value = totals.Kills },
		{ Label = "ASSISTS", Value = totals.Assists },
		{ Label = "HEADSHOTS", Value = totals.Headshots },
		{ Label = "QUESTS", Value = totals.QuestsDone },
		{ Label = "MATCHS", Value = totals.Matches },
		{ Label = "DEATHS", Value = totals.Deaths },
		{ Label = "K/D", Value = string.format("%.2f", ratio) },
		{ Label = "DAMAGE", Value = totals.Damage },
		{ Label = "LEVEL", Value = totals.Level },
	}
end

function CareerController:Setup()
	self.Level = Vide.source(1) :: Vide.Source<number>
	self.Xp = Vide.source(0) :: Vide.Source<number>
	self.XpMax = Vide.source(100) :: Vide.Source<number>
	self.Stats = Vide.source(buildStats(EMPTY)) :: Vide.Source<{ CareerScreen.Stat }>
end

CareerController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Career.Data:onClient(function(data)
		Vide.batch(function()
			self.Level(data.Level)
			self.Xp(data.Xp)
			self.XpMax(data.XpMax)
			self.Stats(buildStats(data))
		end)
	end)
end)

return CareerController
