--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CareerSettings = require(ReplicatedStorage.shared.Career.CareerSettings)
local GameModes = require(ReplicatedStorage.shared.Match.GameModes)
local Progression = require(ReplicatedStorage.shared.Career.Progression)
local WeaponSounds = require(ReplicatedStorage.shared.Weapon.WeaponSounds)
local Modux = require(ServerScriptService.server.Modux)

export type Delta = {
	Xp: number?,
	Kills: number?,
	Deaths: number?,
	Assists: number?,
	Headshots: number?,
	Matches: number?,
	Wins: number?,
}

const COUNT_MAX = 4294967295

const CareerService = Modux.Service("CareerService", {
	Require = { "MatchStatsService", "NetService", "PlayerService", "ProfileService", "ServerRoleService", "TeamService" },
	Priority = 640,
})

function CareerService:Setup()
	self.PendingDamage = {} :: { [Player]: number }
	self.KillLog = {} :: { [Player]: { [Player]: { number } } }
	self.Disposers = {} :: { [Player]: () -> () }
end

function CareerService:Counts(): boolean
	const roleService = self.Dependencies.ServerRoleService
	if not roleService.IsReady or not roleService:IsMatch() then
		return false
	end

	const config = roleService:GetConfig()
	return config ~= nil and config.Mode ~= CareerSettings.PRACTICE_MODE
end

function CareerService:SendState(player: Player)
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile or not self.Dependencies.NetService:IsReady(player) then
		return
	end

	const career = profile.Career()
	const level = profile.Level()

	self.Libs.Net.Career.Data:fireClient(player, {
		Level = level,
		Xp = profile.Xp(),
		XpMax = Progression.XpForLevel(level),
		Wins = profile.Wins(),
		Kills = career.Kills,
		Deaths = career.Deaths,
		Assists = career.Assists,
		Headshots = career.Headshots,
		Matches = career.Matches,
		QuestsDone = career.QuestsDone,
		Damage = career.Damage,
	})
end

function CareerService:Watch(player: Player)
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile or self.Disposers[player] then
		return
	end

	self.Disposers[player] = self.Libs.Charm.effect(function()
		self:SendState(player)
	end)
end

function CareerService:Unwatch(player: Player)
	const dispose = self.Disposers[player]
	if dispose then
		dispose()
		self.Disposers[player] = nil
	end
end

function CareerService:Award(player: Player, delta: Delta)
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	if not profile then
		return
	end

	local damage = 0
	const pending = self.PendingDamage[player]
	if pending then
		damage = math.floor(pending)
		const remainder = pending - damage
		self.PendingDamage[player] = if remainder > 0 then remainder else nil
	end

	const current = profile.Career()
	const career = {
		Kills = math.min(current.Kills + (delta.Kills or 0), COUNT_MAX),
		Deaths = math.min(current.Deaths + (delta.Deaths or 0), COUNT_MAX),
		Assists = math.min(current.Assists + (delta.Assists or 0), COUNT_MAX),
		Headshots = math.min(current.Headshots + (delta.Headshots or 0), COUNT_MAX),
		Matches = math.min(current.Matches + (delta.Matches or 0), COUNT_MAX),
		QuestsDone = current.QuestsDone,
		Damage = math.min(current.Damage + damage, COUNT_MAX),
	}

	const level, xp = Progression.Apply(profile.Level(), profile.Xp(), delta.Xp or 0)

	profiles:Update(player, {
		Level = level,
		Xp = xp,
		Career = career,
		Wins = math.min(profile.Wins() + (delta.Wins or 0), COUNT_MAX),
	})
end

function CareerService:RegisterKill(killer: Player, victim: Player): boolean
	const now = os.clock()
	local victims = self.KillLog[killer]
	if not victims then
		victims = {}
		self.KillLog[killer] = victims
	end

	local stamps = victims[victim]
	if not stamps then
		stamps = {}
		victims[victim] = stamps
	end

	for index = #stamps, 1, -1 do
		if now - stamps[index] >= CareerSettings.FARM_WINDOW then
			table.remove(stamps, index)
		end
	end

	if #stamps >= CareerSettings.FARM_LIMIT then
		return false
	end

	table.insert(stamps, now)
	return true
end

function CareerService:OnKilled(killer: Player, victim: Player, isHeadshot: boolean, assisters: { Player })
	if not self:Counts() then
		return
	end

	const rewarded = self:RegisterKill(killer, victim)
	local killerXp = 0
	if rewarded then
		killerXp = CareerSettings.KILL_XP + (if isHeadshot then CareerSettings.HEADSHOT_XP else 0)
	end

	self:Award(killer, { Kills = 1, Headshots = if isHeadshot then 1 else 0, Xp = killerXp })

	for _, assister in assisters do
		self:Award(assister, { Assists = 1, Xp = if rewarded then CareerSettings.ASSIST_XP else 0 })
	end
end

function CareerService:OnDied(victim: Player)
	if self:Counts() then
		self:Award(victim, { Deaths = 1 })
	end
end

function CareerService:OnDamaged(attacker: Player, _victim: Player, amount: number)
	if self:Counts() then
		self.PendingDamage[attacker] = (self.PendingDamage[attacker] or 0) + amount
	end
end

function CareerService:FlushDamage()
	for player, pending in table.clone(self.PendingDamage) do
		if pending >= 1 then
			self:Award(player, {})
		end
	end
end

function CareerService:Winners(): { [Player]: boolean }
	const winners: { [Player]: boolean } = {}
	const stats = self.Dependencies.MatchStatsService
	const config = self.Dependencies.ServerRoleService:GetConfig()
	const mode = if config then GameModes.Modes[config.Mode] else nil
	if not mode then
		return winners
	end

	if mode.Teams then
		const red = stats.Totals.Red
		const blue = stats.Totals.Blue
		if red == blue then
			return winners
		end

		const winning = if red > blue then "Red" else "Blue"
		for player in stats.Stats do
			if self.Dependencies.TeamService:GetTeam(player) == winning then
				winners[player] = true
			end
		end
		return winners
	end

	const scores: { number } = {}
	for _, playerStats in stats.Stats do
		if playerStats.Score > 0 then
			table.insert(scores, playerStats.Score)
		end
	end
	if #scores == 0 then
		return winners
	end

	table.sort(scores, function(first: number, second: number)
		return first > second
	end)
	const threshold = scores[math.min(CareerSettings.WINNERS_IN_FFA, #scores)]

	for player, playerStats in stats.Stats do
		if playerStats.Score >= threshold then
			winners[player] = true
		end
	end
	return winners
end

function CareerService:OnMatchEnded()
	const winners = self:Winners()

	const draw = next(winners) == nil
	for _, player in Players:GetPlayers() do
		const outcome: WeaponSounds.Outcome = if draw then "Draw" elseif winners[player] then "Victory" else "Defeat"
		player:SetAttribute(WeaponSounds.OUTCOME_ATTRIBUTE, outcome)
	end

	if not self:Counts() then
		return
	end

	for _, player in Players:GetPlayers() do
		self:Award(player, {
			Matches = 1,
			Xp = CareerSettings.MATCH_XP,
			Wins = if winners[player] then 1 else 0,
		})
	end

	table.clear(self.KillLog)
end

function CareerService:Forget(player: Player)
	if (self.PendingDamage[player] or 0) >= 1 then
		self:Award(player, {})
	end

	self:Unwatch(player)
	self.PendingDamage[player] = nil
	self.KillLog[player] = nil
	for _, victims in self.KillLog do
		victims[player] = nil
	end
end

CareerService:OnInit(function(self)
	self:Setup()

	const stats = self.Dependencies.MatchStatsService

	stats.Killed:Connect(function(killer, victim, isHeadshot, assisters)
		self:OnKilled(killer, victim, isHeadshot, assisters)
	end)

	stats.Died:Connect(function(victim)
		self:OnDied(victim)
	end)

	stats.Damaged:Connect(function(attacker, victim, amount)
		self:OnDamaged(attacker, victim, amount)
	end)

	stats.MatchEnded:Connect(function()
		self:OnMatchEnded()
	end)

	stats.MatchStarted:Connect(function()
		for _, player in Players:GetPlayers() do
			player:SetAttribute(WeaponSounds.OUTCOME_ATTRIBUTE, nil)
		end
	end)

	self.Dependencies.ProfileService.Loaded:Connect(function(player)
		self:Watch(player)
	end)

	self.Dependencies.NetService.ClientReady:Connect(function(player)
		self:Watch(player)
		self:SendState(player)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Forget(player)
	end)
end)

CareerService:OnTick(function(self)
	self:FlushDamage()
end, CareerSettings.DAMAGE_FLUSH_INTERVAL)

return CareerService
