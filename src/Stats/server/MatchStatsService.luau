--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Lync = require(ReplicatedStorage.Packages.Lync)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local MedalSettings = require(ReplicatedStorage.shared.KillFeed.MedalSettings)
local StatsNet = require(ReplicatedStorage.shared.Stats.Net)
local StatsSettings = require(ReplicatedStorage.shared.Stats.StatsSettings)
local BotSettings = require(ReplicatedStorage.shared.Bot.BotSettings)
local BotTypes = require(ServerScriptService.server.Bot.BotTypes)
local Modux = require(ServerScriptService.server.Modux)

type Fighter = BotTypes.Fighter

export type PlayerStats = {
	Kills: number,
	Deaths: number,
	Assists: number,
	Headshots: number,
	Score: number,
	Damage: number,
	Ping: number,
}

export type Totals = { Red: number, Blue: number }

export type Run = { Streak: number, Multi: number, LastKill: number }

const MAX_COUNT = 65535
const MAX_SCORE = 1000000
const MAX_PING = 9999

const runs: { [Fighter]: Run } = {}

const MatchStatsService = Modux.Service("MatchStatsService", {
	Require = {
		"BotRegistryService",
		"PlayerService",
		"ServerRoleService",
		"RoundService",
		"VitalService",
		"NetService",
		"TeamService",
	},
	Priority = 650,
})

local function tenths(score: number): number
	return math.round(score * 10)
end

function MatchStatsService:Setup()
	self.Stats = {} :: { [Fighter]: PlayerStats }
	self.Pending = {} :: { [Fighter]: { [Fighter]: boolean } }
	self.Active = false :: boolean
	self.Totals = { Red = 0, Blue = 0 } :: Totals
	self.Killed = self.Libs.Signal.new() :: SignalLib.Signal<Fighter, Fighter, boolean, { Fighter }>
	self.Died = self.Libs.Signal.new() :: SignalLib.Signal<Fighter>
	self.Damaged = self.Libs.Signal.new() :: SignalLib.Signal<Fighter, Fighter, number>
	self.MatchStarted = self.Libs.Signal.new() :: SignalLib.Signal<>
	self.MatchEnded = self.Libs.Signal.new() :: SignalLib.Signal<>
end

function MatchStatsService:IsActive(): boolean
	return self.Active
end

function MatchStatsService:Get(fighter: Fighter): PlayerStats?
	return self.Stats[fighter]
end

function MatchStatsService:TeamOf(fighter: Fighter): StatsNet.Team
	const team = self.Dependencies.TeamService:GetTeam(fighter)
	return if team == "Red" or team == "Blue" then team else "None"
end

function MatchStatsService:PushRow(fighter: Fighter)
	const stats = self.Stats[fighter]
	if not stats or not self.Dependencies.NetService:IsRunning() then
		return
	end

	self.Libs.Net.Stats.Rows:update(fighter.UserId, {
		Kills = math.min(stats.Kills, MAX_COUNT),
		Deaths = math.min(stats.Deaths, MAX_COUNT),
		Assists = math.min(stats.Assists, MAX_COUNT),
		Headshots = math.min(stats.Headshots, MAX_COUNT),
		Score = math.min(stats.Score, MAX_SCORE),
		Ping = stats.Ping,
		Team = self:TeamOf(fighter),
	})
end

function MatchStatsService:PublishTotals(to: Lync.Recipient)
	if not self.Dependencies.NetService:IsRunning() then
		return
	end

	self.Libs.Net.Stats.Totals:fireClient(to, {
		Red = math.min(self.Totals.Red, MAX_SCORE),
		Blue = math.min(self.Totals.Blue, MAX_SCORE),
	})
end

function MatchStatsService:RecomputeTotals()
	local red = 0
	local blue = 0
	for fighter, stats in self.Stats do
		const team = self.Dependencies.TeamService:GetTeam(fighter)
		if team == "Red" then
			red += stats.Score
		elseif team == "Blue" then
			blue += stats.Score
		end
	end

	if red == self.Totals.Red and blue == self.Totals.Blue then
		return
	end

	self.Totals.Red = red
	self.Totals.Blue = blue
	self:PublishTotals(self.Dependencies.NetService.Audience)
end

function MatchStatsService:Add(fighter: Fighter)
	if not self.Active or self.Stats[fighter] ~= nil then
		return
	end

	const player = BotTypes.AsPlayer(fighter)
	if player and not player:IsDescendantOf(Players) then
		return
	end

	const team = self:TeamOf(fighter)
	const stats: PlayerStats = {
		Kills = 0,
		Deaths = 0,
		Assists = 0,
		Headshots = 0,
		Score = 0,
		Damage = 0,
		Ping = 0,
	}
	self.Stats[fighter] = stats

	const bot = BotTypes.AsBot(fighter)
	if bot then
		stats.Ping = bot.Ping
	end

	if self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.Stats.Rows:add(fighter.UserId, {
			Kills = 0,
			Deaths = 0,
			Assists = 0,
			Headshots = 0,
			Score = 0,
			Ping = stats.Ping,
			Team = team,
		})
	end
end

local function advanceRun(killer: Fighter): Run
	const now = os.clock()
	const existing = runs[killer]
	const run: Run = existing or { Streak = 0, Multi = 0, LastKill = -math.huge }
	run.Multi = if now - run.LastKill <= MedalSettings.MultiKillWindow then run.Multi + 1 else 1
	run.Streak += 1
	run.LastKill = now
	runs[killer] = run
	return run
end

function MatchStatsService:Medal(killer: Fighter, isHeadshot: boolean)
	const run = advanceRun(killer)

	const player = BotTypes.AsPlayer(killer)
	const netService = self.Dependencies.NetService
	if not player or not netService:IsRunning() or not netService:IsReady(player) then
		return
	end

	self.Libs.Net.KillFeed.Medal:fireClient(player, {
		Headshot = isHeadshot,
		Multi = math.clamp(run.Multi, 1, MedalSettings.MaxMulti),
		Streak = math.min(run.Streak, MedalSettings.MaxStreak),
	})
end

function MatchStatsService:Remove(fighter: Fighter)
	runs[fighter] = nil
	self.Pending[fighter] = nil
	for _, attackers in self.Pending do
		attackers[fighter] = nil
	end

	if self.Stats[fighter] == nil then
		return
	end

	self.Stats[fighter] = nil
	if self.Dependencies.NetService:IsRunning() and self.Libs.Net.Stats.Rows:get(fighter.UserId) then
		self.Libs.Net.Stats.Rows:remove(fighter.UserId)
	end
	self:RecomputeTotals()
end

function MatchStatsService:Reset()
	table.clear(self.Pending)
	table.clear(runs)

	for fighter, stats in self.Stats do
		stats.Kills = 0
		stats.Deaths = 0
		stats.Assists = 0
		stats.Headshots = 0
		stats.Score = 0
		stats.Damage = 0
		self:PushRow(fighter)
	end

	self:RecomputeTotals()
end

function MatchStatsService:Activate()
	self.Active = true
	for _, player in Players:GetPlayers() do
		self:Add(player)
	end
	for _, bot in self.Dependencies.BotRegistryService:All() do
		self:Add(bot)
	end
	self:RecomputeTotals()
end

function MatchStatsService:ClearPending(victim: Fighter)
	self.Pending[victim] = nil
end

function MatchStatsService:RecordDamage(attacker: Fighter, victim: Fighter, amount: number)
	if not self.Active or attacker == victim or amount <= 0 then
		return
	end

	const stats = self.Stats[attacker]
	if not stats or self.Stats[victim] == nil then
		return
	end

	stats.Damage += amount

	local attackers = self.Pending[victim]
	if not attackers then
		attackers = {}
		self.Pending[victim] = attackers
	end
	attackers[attacker] = true
	self.Damaged:Fire(attacker, victim, amount)
end

function MatchStatsService:RecordKill(killer: Fighter, victim: Fighter, isHeadshot: boolean)
	if not self.Active or killer == victim then
		return
	end

	const killerStats = self.Stats[killer]
	if not killerStats or self.Stats[victim] == nil then
		return
	end

	killerStats.Kills += 1
	killerStats.Score += tenths(if isHeadshot then StatsSettings.HEADSHOT_KILL_SCORE else StatsSettings.KILL_SCORE)
	if isHeadshot then
		killerStats.Headshots += 1
	end
	self:PushRow(killer)

	const assisters: { Fighter } = {}
	const attackers = self.Pending[victim]
	if attackers then
		for attacker in attackers do
			const stats = self.Stats[attacker]
			if attacker ~= killer and stats then
				stats.Assists += 1
				stats.Score += tenths(StatsSettings.ASSIST_SCORE)
				table.insert(assisters, attacker)
				self:PushRow(attacker)
			end
		end
	end
	self.Pending[victim] = nil

	self:Medal(killer, isHeadshot)
	self:RecomputeTotals()
	self.Killed:Fire(killer, victim, isHeadshot, assisters)
end

function MatchStatsService:RecordDeath(victim: Fighter)
	if not self.Active then
		return
	end

	const stats = self.Stats[victim]
	if not stats then
		return
	end

	stats.Deaths += 1
	runs[victim] = nil
	self:PushRow(victim)
	self.Died:Fire(victim)
end

function MatchStatsService:UpdatePing()
	for fighter, stats in self.Stats do
		const player = BotTypes.AsPlayer(fighter)
		const ping = if player
			then math.clamp(math.round(player:GetNetworkPing() * 1000), 0, MAX_PING)
			else math.clamp(stats.Ping + math.random(-6, 6), BotSettings.PingMin, BotSettings.PingMax)
		if ping ~= stats.Ping then
			stats.Ping = ping
			self:PushRow(fighter)
		end
	end
end

MatchStatsService:OnInit(function(self)
	self:Setup()

	const playerService = self.Dependencies.PlayerService
	const vitalService = self.Dependencies.VitalService

	playerService.PlayerAdded:Connect(function(player)
		self:Add(player)
	end)

	playerService.PlayerRemoving:Connect(function(player)
		self:Remove(player)
	end)

	playerService.CharacterAdded:Connect(function(player)
		self:ClearPending(player)
	end)

	vitalService.Died:Connect(function(victim)
		self:RecordDeath(victim)
	end)

	vitalService.Restored:Connect(function(player)
		self:ClearPending(player)
	end)

	const botRegistry = self.Dependencies.BotRegistryService

	botRegistry.Added:Connect(function(bot)
		self:Add(bot)
	end)

	botRegistry.Removing:Connect(function(bot)
		self:Remove(bot)
	end)

	botRegistry.Died:Connect(function(bot)
		self:RecordDeath(bot)
	end)

	self.Dependencies.TeamService.Changed:Connect(function(fighter)
		self:PushRow(fighter)
		self:RecomputeTotals()
	end)
end)

MatchStatsService:OnStart(function(self)
	const roleService = self.Dependencies.ServerRoleService
	roleService:OnReady(function()
		if roleService:IsMatch() then
			self:Activate()
		end
	end)

	self.Dependencies.NetService.ClientReady:Connect(function(player)
		self:PublishTotals(player)
	end)

	self.Libs.Charm.subscribe(self.Dependencies.RoundService.Status, function(status, previous)
		if not self.Active then
			return
		end

		if status == "Starting" then
			self:Reset()
		end

		if status == "Match" then
			self.MatchStarted:Fire()
		elseif previous == "Match" then
			self.MatchEnded:Fire()
		end
	end)
end)

MatchStatsService:OnTick(function(self)
	if self.Active then
		self:UpdatePing()
	end
end, StatsSettings.PING_INTERVAL)

return MatchStatsService
