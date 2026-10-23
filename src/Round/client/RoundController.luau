--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RoundNet = require(ReplicatedStorage.shared.Round.Net)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WeaponSounds = require(ReplicatedStorage.shared.Weapon.WeaponSounds)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local MatchSummary = require(StarterPlayer.StarterPlayerScripts.client.Round.MatchSummary)

export type Status = RoundNet.Status

const LABELS: { [string]: string } = {
	Starting = "Starting",
	Match = "Match",
	Intermission = "Intermission",
	Vote = "Vote",
}

const OUTCOME_DELAY = 1.5
const PRACTICE_MODE = "Practice"
const PRACTICE_LABEL = "Practice"
const SUMMARY_SECONDS = 12
const SUMMARY_DISPLAY_ORDER = 15

const EMPTY_SUMMARY: MatchSummary.Summary = {
	Outcome = "Draw",
	Placement = 0,
	Players = 0,
	Kills = 0,
	Deaths = 0,
	Assists = 0,
	Score = 0,
	XpGained = 0,
	GemsGained = 0,
	Level = 1,
	LevelsGained = 0,
	Xp = 0,
	XpMax = 1,
	Counted = false,
}

const COLOR_RETURN_SECONDS = 3
const GRAY_SMOOTHING = 6
const GRAY_TICK_RATE = 30

const RoundController = Modux.Controller("RoundController", {
	Require = { "ColorCorrectionController", "GameStateController" },
	Priority = 800,
})

function RoundController:Setup()
	self.Status = Vide.source("Starting") :: Vide.Source<Status>
	self.Seconds = Vide.source(0) :: Vide.Source<number>
	self.Summary = Vide.source(EMPTY_SUMMARY) :: Vide.Source<MatchSummary.Summary>
	self.SummaryVisible = Vide.source(false) :: Vide.Source<boolean>
	self.SummaryToken = 0 :: number
	self.Gray = 0 :: number
end

function RoundController:ShowSummary(summary: MatchSummary.Summary)
	self.SummaryToken += 1
	const token = self.SummaryToken
	Vide.batch(function()
		self.Summary(summary)
		self.SummaryVisible(true)
	end)

	task.delay(SUMMARY_SECONDS, function()
		if self.SummaryToken == token then
			self:HideSummary()
		end
	end)
end

function RoundController:HideSummary()
	self.SummaryToken += 1
	self.SummaryVisible(false)
end

function RoundController:MountSummary()
	Vide.mount(function()
		return Vide.create("ScreenGui")({
			Name = "MatchSummaryUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = SUMMARY_DISPLAY_ORDER,

			MatchSummary({
				Visible = self.SummaryVisible,
				Summary = self.Summary,
				OnClose = function()
					self:HideSummary()
				end,
			}),
		})
	end, Players.LocalPlayer:WaitForChild("PlayerGui"))
end

local function formatSeconds(seconds: number): string
	const whole = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", whole // 60, whole % 60)
end

function RoundController:Label(): string
	if workspace:GetAttribute("GameMode") == PRACTICE_MODE then
		return PRACTICE_LABEL
	end
	return `{LABELS[self.Status()] or self.Status()}  {formatSeconds(self.Seconds())}`
end

function RoundController:Clock(): string
	if workspace:GetAttribute("GameMode") == PRACTICE_MODE then
		return ""
	end
	return formatSeconds(self.Seconds())
end

RoundController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Round.State:onClient(function(payload)
		const previous = self.Status()
		self.Status(payload.Status)
		self.Seconds(payload.Seconds)

		if payload.Status == "Intermission" and previous == "Match" then
			WeaponSounds.Play2D(WeaponSounds.MATCH_END)
		elseif payload.Status ~= "Intermission" and self.SummaryVisible() then
			self:HideSummary()
		end
	end)

	self.Libs.Net.Career.Summary:onClient(function(summary)
		self:ShowSummary(summary :: MatchSummary.Summary)
	end)

	const localPlayer = Players.LocalPlayer
	localPlayer:GetAttributeChangedSignal(WeaponSounds.OUTCOME_ATTRIBUTE):Connect(function()
		const outcome = localPlayer:GetAttribute(WeaponSounds.OUTCOME_ATTRIBUTE)
		if type(outcome) == "string" then
			task.delay(OUTCOME_DELAY, WeaponSounds.Play2D, outcome)
		end
	end)
end)

function RoundController:TargetGray(): number
	if self.Dependencies.GameStateController.State() ~= "Starting" then
		return 0
	end
	if workspace:GetAttribute("GameMode") == PRACTICE_MODE then
		return 0
	end
	return math.clamp(self.Seconds() / COLOR_RETURN_SECONDS, 0, 1)
end

function RoundController:StepGray(deltaTime: number)
	const target = self:TargetGray()
	const alpha = 1 - math.exp(-GRAY_SMOOTHING * deltaTime)
	self.Gray += (target - self.Gray) * alpha
	if math.abs(target - self.Gray) < 0.001 then
		self.Gray = target
	end
	self.Dependencies.ColorCorrectionController:SetGray(self.Gray)
end

RoundController:OnTick(function(self)
	self:StepGray(1 / GRAY_TICK_RATE)
end, GRAY_TICK_RATE)

RoundController:OnStart(function(self)
	self:MountSummary()
end)

return RoundController
