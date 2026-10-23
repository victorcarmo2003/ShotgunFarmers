--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local BotTypes = require(ServerScriptService.server.Bot.BotTypes)
local Modux = require(ServerScriptService.server.Modux)

const ROUND_STEPS: { [number]: string } = {
	[2] = "Round2",
	[3] = "Round3",
	[5] = "Round5",
}

const RoundsFunnelService = Modux.Service("RoundsFunnelService", {
	Require = {
		"CareerService",
		"FunnelService",
		"MapVoteService",
		"MatchStatsService",
		"PlayerService",
		"PracticeService",
		"RoundService",
		"ServerRoleService",
	},
	Priority = 600,
})

function RoundsFunnelService:Setup()
	self.Active = false :: boolean
	self.Rounds = {} :: { [Player]: number }
	self.Outcomes = {} :: { [Player]: string }
end

function RoundsFunnelService:Step(player: Player, step: string, fields: { string }?)
	self.Dependencies.FunnelService:Step(player, "Rounds", step, fields)
end

function RoundsFunnelService:Mix(): string
	for fighter in self.Dependencies.MatchStatsService.Stats do
		if not BotTypes.AsPlayer(fighter) then
			return "WithBots"
		end
	end
	return "HumansOnly"
end

function RoundsFunnelService:Join(player: Player)
	if not self.Active or self.Rounds[player] ~= nil then
		return
	end

	const config = self.Dependencies.ServerRoleService:GetConfig()
	self.Rounds[player] = if self.Dependencies.RoundService.Status() == "Match" then 1 else 0
	self:Step(player, "JoinedMatch", { if config then config.Mode else "Unknown" })
end

function RoundsFunnelService:Resolved(player: Player, outcome: string, placement: number, total: number, sent: boolean)
	if not self.Active or self.Rounds[player] == nil then
		return
	end

	self.Outcomes[player] = outcome
	self:Step(player, "FinishedRound", { outcome, `{placement}/{total}`, self:Mix() })
	if sent then
		self:Step(player, "SawSummary", { outcome })
	end
end

function RoundsFunnelService:RoundStarted()
	for _, player in Players:GetPlayers() do
		const rounds = self.Rounds[player]
		if rounds == nil then
			continue
		end

		const count = rounds + 1
		self.Rounds[player] = count
		const step = ROUND_STEPS[count]
		if step then
			self:Step(player, step, { self.Outcomes[player] or "None" })
		end
	end
end

function RoundsFunnelService:Leave(player: Player, reason: string)
	if self.Rounds[player] == nil then
		return
	end

	self.Dependencies.FunnelService:Drop(player, "Rounds", reason, { self.Outcomes[player] or "None" })
	self.Rounds[player] = nil
	self.Outcomes[player] = nil
end

function RoundsFunnelService:Activate()
	const roles = self.Dependencies.ServerRoleService
	if not roles:IsMatch() or self.Dependencies.PracticeService:IsPractice() then
		return
	end

	self.Active = true
	for _, player in Players:GetPlayers() do
		self:Join(player)
	end
end

RoundsFunnelService:OnInit(function(self)
	self:Setup()
end)

RoundsFunnelService:OnStart(function(self)
	self.Dependencies.ServerRoleService:OnReady(function()
		self:Activate()
	end)

	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
		self:Join(player)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Leave(player, "Left")
	end)

	self.Dependencies.CareerService.Resolved:Connect(function(player, outcome, placement, total, sent)
		self:Resolved(player, outcome, placement, total, sent)
	end)

	self.Dependencies.MapVoteService.Voted:Connect(function(player)
		if self.Active and self.Rounds[player] ~= nil then
			self:Step(player, "VotedMap")
		end
	end)

	self.Dependencies.MatchStatsService.MatchStarted:Connect(function()
		if self.Active then
			self:RoundStarted()
		end
	end)
end)

return RoundsFunnelService
