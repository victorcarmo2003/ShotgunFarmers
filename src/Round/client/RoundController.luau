--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RoundNet = require(ReplicatedStorage.shared.Round.Net)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Status = RoundNet.Status

const LABELS: { [string]: string } = {
	Starting = "Preparando",
	Match = "Partida",
	Intermission = "Intervalo",
	Vote = "Votacao",
}

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
	return `{LABELS[self.Status()] or self.Status()}  {formatSeconds(self.Seconds())}`
end

RoundController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Round.State:onClient(function(payload)
		self.Status(payload.Status)
		self.Seconds(payload.Seconds)
	end)
end)

return RoundController
