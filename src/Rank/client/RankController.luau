--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local RankSettings = require(ReplicatedStorage.shared.Rank.RankSettings)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

type Category = RankSettings.Category
type Entry = RankSettings.Entry

const RankController = Modux.Controller("RankController", { Priority = 390 })

function RankController:Setup()
	self.Boards = Vide.source({}) :: Vide.Source<{ [Category]: { Entry } }>
	self.Mine = Vide.source({}) :: Vide.Source<{ [Category]: number }>
end

RankController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Rank.Board:onClient(function(data)
		const boards = table.clone(self.Boards())
		boards[data.Category :: Category] = data.Entries
		self.Boards(boards)
	end)

	self.Libs.Net.Rank.Mine:onClient(function(data)
		const mine: { [Category]: number } = {}
		for _, item in data do
			mine[item.Category :: Category] = item.Value
		end
		self.Mine(mine)
	end)
end)

return RankController
