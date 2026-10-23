--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local GameModes = require(ReplicatedStorage.shared.Match.GameModes)
local GetThumbnail = require(ReplicatedStorage.shared.Utils.GetThumbnail)
local StatsNet = require(ReplicatedStorage.shared.Stats.Net)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local FarmPalette = require(StarterPlayer.StarterPlayerScripts.client.Interface.FarmPalette)
local LeaderstatsScreen = require(StarterPlayer.StarterPlayerScripts.client.Leaderstats.LeaderstatsScreen)
local TeamScore = require(StarterPlayer.StarterPlayerScripts.client.Stats.TeamScore)
local KillRanking = require(StarterPlayer.StarterPlayerScripts.client.Stats.KillRanking)

export type Record = {
	Kills: number,
	Deaths: number,
	Assists: number,
	Headshots: number,
	Score: number,
	Ping: number,
	Team: StatsNet.Team,
}

const SCORE_DIVISOR = 10
const CORE_GUI_ATTEMPTS = 20
const CORE_GUI_RETRY = 0.5
const RANKING_PER_TEAM = 4

const LeaderstatsController = Modux.Controller("LeaderstatsController", {
	Require = {
		"BotController",
		"CareerController",
		"GameStateController",
		"InputController",
		"MenuEffectsController",
		"RoundController",
	},
	Priority = 410,
})

function LeaderstatsController:Setup()
	self.Records = {} :: { [number]: Record }
	self.Thumbnails = {} :: { [number]: string }
	self.Loading = {} :: { [number]: boolean }
	self.Rows = Vide.source({}) :: Vide.Source<{ LeaderstatsScreen.Row }>
	self.Red = Vide.source({}) :: Vide.Source<{ LeaderstatsScreen.Row }>
	self.Blue = Vide.source({}) :: Vide.Source<{ LeaderstatsScreen.Row }>
	self.Totals = Vide.source({ Red = 0, Blue = 0 }) :: Vide.Source<{ Red: number, Blue: number }>
	self.Mode = Vide.source("FFA") :: Vide.Source<LeaderstatsScreen.Mode>
	self.Held = Vide.source(false) :: Vide.Source<boolean>
	self.LocalTeam = Vide.source("None" :: TeamScore.Team) :: Vide.Source<TeamScore.Team>
	self.Ranking = Vide.source({}) :: Vide.Source<{ KillRanking.Entry }>
	self.ModeName = Vide.source("") :: Vide.Source<string>
	self.Unmount = nil :: (() -> ())?
end

local function byScore(first: LeaderstatsScreen.Row, second: LeaderstatsScreen.Row): boolean
	if first.Score ~= second.Score then
		return first.Score > second.Score
	end
	if first.Kills ~= second.Kills then
		return first.Kills > second.Kills
	end
	return first.Name < second.Name
end

function LeaderstatsController:LoadThumbnail(player: Player)
	const userId = player.UserId
	if self.Thumbnails[userId] ~= nil or self.Loading[userId] then
		return
	end
	self.Loading[userId] = true

	task.spawn(function()
		const content = GetThumbnail.HeadShot(player)
		self.Loading[userId] = nil
		self.Thumbnails[userId] = content or ""
		self:Refresh()
	end)
end

function LeaderstatsController:LoadBotThumbnail(userId: number)
	if self.Thumbnails[userId] ~= nil or self.Loading[userId] then
		return
	end
	const _, member = self.Dependencies.BotController:FindByUserId(userId)
	if not member then
		return
	end
	self.Loading[userId] = true

	task.spawn(function()
		const content = self.Dependencies.BotController:Thumbnail(member)
		self.Loading[userId] = nil
		self.Thumbnails[userId] = content
		self:Refresh()
	end)
end

function LeaderstatsController:Identify(userId: number): (string?, boolean)
	const player = Players:GetPlayerByUserId(userId)
	if player then
		self:LoadThumbnail(player)
		return player.DisplayName, player == Players.LocalPlayer
	end

	const _, member = self.Dependencies.BotController:FindByUserId(userId)
	if member then
		self:LoadBotThumbnail(userId)
		return member.DisplayName, false
	end
	return nil, false
end

function LeaderstatsController:Refresh()
	const everyone: { LeaderstatsScreen.Row } = {}
	const red: { LeaderstatsScreen.Row } = {}
	const blue: { LeaderstatsScreen.Row } = {}

	for userId, record in self.Records do
		const name, isLocal = self:Identify(userId)
		if name then
			const row: LeaderstatsScreen.Row = {
				Name = name,
				Score = record.Score / SCORE_DIVISOR,
				Ping = record.Ping,
				Kills = record.Kills,
				Deaths = record.Deaths,
				Assists = record.Assists,
				Image = self.Thumbnails[userId],
				IsLocal = isLocal,
			}

			table.insert(everyone, row)
			if record.Team == "Red" then
				table.insert(red, row)
			elseif record.Team == "Blue" then
				table.insert(blue, row)
			end
		end
	end

	table.sort(everyone, byScore)
	table.sort(red, byScore)
	table.sort(blue, byScore)

	const ranking: { KillRanking.Entry } = {}
	local topKills = 0
	for userId, record in self.Records do
		const name, isLocal = self:Identify(userId)
		if name then
			topKills = math.max(topKills, record.Kills)
			table.insert(ranking, {
				UserId = userId,
				Kills = record.Kills,
				Image = self.Thumbnails[userId] or "",
				Team = record.Team,
				IsLocal = isLocal,
				Leader = false,
			})
		end
	end
	table.sort(ranking, function(first: KillRanking.Entry, second: KillRanking.Entry): boolean
		if first.Kills ~= second.Kills then
			return first.Kills > second.Kills
		end
		return first.UserId < second.UserId
	end)
	for _, entry in ranking do
		entry.Leader = topKills > 0 and entry.Kills == topKills
	end

	local shownRanking = ranking
	if self.Mode() == "TDM" then
		const grouped: { KillRanking.Entry } = {}
		for _, team in { "Red", "Blue" } do
			local taken = 0
			for _, entry in ranking do
				if entry.Team == team and taken < RANKING_PER_TEAM then
					table.insert(grouped, entry)
					taken += 1
				end
			end
		end
		shownRanking = grouped
	end

	const own = self.Records[Players.LocalPlayer.UserId]
	Vide.batch(function()
		self.Rows(everyone)
		self.Red(red)
		self.Blue(blue)
		self.LocalTeam(if own then own.Team else "None")
		self.Ranking(shownRanking)
	end)
end

function LeaderstatsController:ApplyMode()
	const value = workspace:GetAttribute("GameMode")
	const mode = if typeof(value) == "string" then GameModes.Modes[value] else nil
	self.Mode(if mode and mode.Teams then "TDM" else "FFA")
	self.ModeName(if mode then mode.DisplayName else "")
end

function LeaderstatsController:IsShown(): boolean
	return self.Held() or self.Dependencies.GameStateController.State() == "Intermission"
end

function LeaderstatsController:BindKeys()
	const handle = self.Dependencies.InputController:Bind({
		Name = "Leaderstats",
		Key = Enum.KeyCode.Tab,
		Priority = 10,
		Requires = "Hud",
		Touch = {
			Text = "SCORE",
			Color = FarmPalette.Sky,
			Order = 2,
			Toggle = true,
		},
	})

	handle.OnPress(function()
		self.Held(true)
		self.Dependencies.MenuEffectsController:Open("Leaderstats")
	end)

	handle.OnRelease(function()
		self.Held(false)
		self.Dependencies.MenuEffectsController:Close("Leaderstats")
	end)
end

function LeaderstatsController:Mount()
	const gameState = self.Dependencies.GameStateController
	const round = self.Dependencies.RoundController
	const career = self.Dependencies.CareerController
	const localPlayer = Players.LocalPlayer
	const playerGui = localPlayer:WaitForChild("PlayerGui")

	const playerImage = Vide.source("")
	task.spawn(function()
		const content = GetThumbnail.HeadShot(localPlayer)
		playerImage(content or "")
	end)

	self.Unmount = Vide.mount(function()
		return Vide.create("ScreenGui")({
			Name = "LeaderstatsUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 5,
			Enabled = function()
				return gameState:IsInMatch()
			end,

			LeaderstatsScreen({
				Visible = function()
					return self:IsShown()
				end,
				Mode = self.Mode,
				Players = self.Rows,
				Red = self.Red,
				Blue = self.Blue,
				TimeLeft = round.Seconds,
				PlayerName = function()
					return localPlayer.DisplayName
				end,
				PlayerImage = playerImage,
				Level = career.Level,
				Xp = career.Xp,
				XpMax = career.XpMax,
			}),
		})
	end, playerGui)
end

function LeaderstatsController:DisableCorePlayerList()
	task.spawn(function()
		for _ = 1, CORE_GUI_ATTEMPTS do
			const ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			end)
			if ok then
				return
			end
			task.wait(CORE_GUI_RETRY)
		end
	end)
end

LeaderstatsController:OnInit(function(self)
	self:Setup()

	self:ApplyMode()
	workspace:GetAttributeChangedSignal("GameMode"):Connect(function()
		self:ApplyMode()
	end)

	const rows = self.Libs.Net.Stats.Rows

	rows:onAdded(function(userId, record)
		self.Records[userId] = record
		self:Refresh()
	end)

	rows:onChanged(function(userId, record)
		self.Records[userId] = record
		self:Refresh()
	end)

	rows:onRemoved(function(userId)
		self.Records[userId] = nil
		self:Refresh()
	end)

	self.Libs.Net.Stats.Totals:onClient(function(payload)
		self.Totals({ Red = payload.Red / SCORE_DIVISOR, Blue = payload.Blue / SCORE_DIVISOR })
	end)

	Players.PlayerAdded:Connect(function()
		self:Refresh()
	end)

	self.Dependencies.BotController.Changed:Connect(function()
		self:Refresh()
	end)
end)

LeaderstatsController:OnStart(function(self)
	self:BindKeys()
	self:DisableCorePlayerList()

	task.spawn(function()
		self:Mount()
	end)
end)

return LeaderstatsController
