local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FSM = require(ReplicatedStorage.Shared.Utils.FSM)
local RoundSettings = require(ReplicatedStorage.Shared.Settings.RoundSettings)
local Modux = require(ReplicatedStorage.Shared.Modux)

export type RoundState = "Starting" | "Match" | "Intermission" | "Vote"

local GameService = Modux.Service("GameService"):Import("DayNightService")

-- Ordem fixa de alternância do round: Starting -> Match -> Intermission -> Vote -> Starting
local ROUND_ORDER: { RoundState } = { "Starting", "Match", "Intermission", "Vote" }

local STATE_SIGNALS = {
	Starting = "OnStarting",
	Match = "OnMatch",
	Intermission = "OnIntermission",
	Vote = "OnVote",
}

GameService.CurrentState = "Starting" :: RoundState
GameService.TimeLeft = RoundSettings.Starting :: number

GameService.OnStarting = GameService.Signal.new() :: Modux.Signal<>
GameService.OnMatch = GameService.Signal.new() :: Modux.Signal<>
GameService.OnIntermission = GameService.Signal.new() :: Modux.Signal<>
GameService.OnVote = GameService.Signal.new() :: Modux.Signal<>

GameService.State = FSM.new<<RoundState>>("Starting", {
	Starting = { "Match" },
	Match = { "Intermission" },
	Intermission = { "Vote" },
	Vote = { "Starting" },
}) :: FSM.FSM<RoundState>

GameService.ReplicateRoundState = function(self)
	self.Network.Packages.RoundState:send({
		State = self.CurrentState,
		Seconds = self.TimeLeft,
	}, self.Network.all)
end

GameService.AdvanceState = function(self)
	local current = self.State:GetState()
	local currentIndex = table.find(ROUND_ORDER, current) :: number
	local nextState = ROUND_ORDER[currentIndex % #ROUND_ORDER + 1]

	if not self.State:Transition(nextState) then
		return
	end

	self.CurrentState = nextState
	self.TimeLeft = RoundSettings[nextState]
	self:ReplicateRoundState()

	local signalName = STATE_SIGNALS[nextState]
	local signal = signalName and self[signalName]
	if signal then
		(signal :: Modux.Signal<>):Fire()
	end
end

GameService:OnInit(function(self)
	self.TimeLeft = RoundSettings.Starting
	self:ReplicateRoundState()
	self.DayNightService:StartCycle()
	-- Spawn/respawn de jogador é responsabilidade do SpawnService (via PlayerService) --
	-- FFA contínuo, não depende do estado do round.
end)

GameService:OnTick(function(self)
	if self.TimeLeft <= 0 then
		self:AdvanceState()
		return
	end

	self.TimeLeft -= 1
	self:ReplicateRoundState()
end, Modux.TickRate.Hz1)

return GameService
