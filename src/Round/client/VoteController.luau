--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Maps = require(ReplicatedStorage.shared.Match.Maps)
local Vide = require(ReplicatedStorage.Packages.Vide)
local VoteMaps = require(ReplicatedStorage.shared.Round.VoteMaps)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local VoteMenu = require(StarterPlayer.StarterPlayerScripts.client.Round.VoteMenu)

const MODE_ATTRIBUTE = "GameMode"
const RESULT_HOLD = 2

const VoteController = Modux.Controller("VoteController", {
	Require = { "RoundController" },
	Priority = 790,
})

local function readMode(): string
	const mode = workspace:GetAttribute(MODE_ATTRIBUTE)
	return if typeof(mode) == "string" then mode else ""
end

function VoteController:Setup()
	self.Mode = Vide.source(readMode()) :: Vide.Source<string>
	self.Votes = Vide.source({} :: { [number]: number }) :: Vide.Source<{ [number]: number }>
	self.MyVote = Vide.source(0) :: Vide.Source<number>
	self.Winner = Vide.source(0) :: Vide.Source<number>
	self.Holding = Vide.source(false) :: Vide.Source<boolean>
	self.HoldToken = 0 :: number
	self.Unmount = nil :: (() -> ())?
end

function VoteController:Entries(): { VoteMenu.Option }
	const entries: { VoteMenu.Option } = {}
	const votes = self.Votes()
	for index, name in VoteMaps.list(self.Mode()) do
		const count = votes[index]
		if count ~= nil then
			const map = Maps[name]
			table.insert(entries, {
				Name = name,
				DisplayName = if map then map.DisplayName else name,
				Votes = count,
			})
		end
	end
	return entries
end

function VoteController:SetVotes(index: number, count: number?)
	const updated = table.clone(self.Votes())
	updated[index] = count
	self.Votes(updated)
end

function VoteController:Cast(index: number)
	if self.Winner() > 0 or self.Dependencies.RoundController.Status() ~= "Vote" then
		return
	end

	if self.MyVote() == index then
		return
	end

	self.MyVote(index)
	self.Libs.Net.Round.CastVote:fireServer({ Option = index })
end

function VoteController:ShowResult(index: number)
	self.HoldToken += 1
	const token = self.HoldToken

	Vide.batch(function()
		self.Winner(index)
		self.Holding(true)
	end)

	task.delay(RESULT_HOLD, function()
		if self.HoldToken ~= token then
			return
		end

		Vide.batch(function()
			self.Winner(0)
			self.Holding(false)
			self.MyVote(0)
			self.Votes({})
		end)
	end)
end

function VoteController:IsVisible(): boolean
	const open = self.Dependencies.RoundController.Status() == "Vote" or self.Holding()
	return open and #self:Entries() > 0
end

function VoteController:Mount()
	const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	self.Unmount = Vide.mount(function()
		return Vide.create("ScreenGui")({
			Name = "VoteUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 20,

			VoteMenu({
				Visible = function()
					return self:IsVisible()
				end,
				Options = function()
					return self:Entries()
				end,
				MyVote = self.MyVote,
				Winner = self.Winner,
				Seconds = self.Dependencies.RoundController.Seconds,
				OnVote = function(index: number)
					self:Cast(index)
				end,
			}),
		})
	end, playerGui)
end

VoteController:OnInit(function(self)
	self:Setup()

	workspace:GetAttributeChangedSignal(MODE_ATTRIBUTE):Connect(function()
		self.Mode(readMode())
	end)

	const options = self.Libs.Net.Round.VoteOptions

	options:onAdded(function(index, record)
		if index == 1 then
			self.MyVote(0)
		end
		self:SetVotes(index, record.Votes)
	end)

	options:onChanged(function(index, record)
		self:SetVotes(index, record.Votes)
	end)

	options:onRemoved(function(index)
		if self.Holding() then
			return
		end
		self:SetVotes(index, nil)
	end)

	self.Libs.Net.Round.VoteResult:onClient(function(payload)
		self:ShowResult(payload.Option)
	end)
end)

VoteController:OnStart(function(self)
	task.spawn(function()
		self:Mount()
	end)
end)

return VoteController
