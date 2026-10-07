--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RoundNet = require(ReplicatedStorage.shared.Round.Net)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WeaponSounds = require(ReplicatedStorage.shared.Weapon.WeaponSounds)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Status = RoundNet.Status

const LABELS: { [string]: string } = {
	Starting = "Preparando",
	Match = "Partida",
	Intermission = "Intervalo",
	Vote = "Votacao",
}

const OUTCOME_DELAY = 1.5
const PRACTICE_MODE = "Practice"
const PRACTICE_LABEL = "Treino"

const RoundController = Modux.Controller("RoundController", { Priority = 800 })

function RoundController:Setup()
	self.Status = Vide.source("Starting") :: Vide.Source<Status>
	self.Seconds = Vide.source(0) :: Vide.Source<number>
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

RoundController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Round.State:onClient(function(payload)
		const previous = self.Status()
		self.Status(payload.Status)
		self.Seconds(payload.Seconds)

		if payload.Status == "Intermission" and previous == "Match" then
			WeaponSounds.Play2D(WeaponSounds.MATCH_END)
		end
	end)

	const localPlayer = Players.LocalPlayer
	localPlayer:GetAttributeChangedSignal(WeaponSounds.OUTCOME_ATTRIBUTE):Connect(function()
		const outcome = localPlayer:GetAttribute(WeaponSounds.OUTCOME_ATTRIBUTE)
		if type(outcome) == "string" then
			task.delay(OUTCOME_DELAY, WeaponSounds.Play2D, outcome)
		end
	end)
end)

return RoundController
