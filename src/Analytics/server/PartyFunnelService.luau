--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const ROUNDS_GOAL = 3

const PartyFunnelService = Modux.Service("PartyFunnelService", {
	Require = {
		"FunnelService",
		"InviteService",
		"MatchStatsService",
		"PlayerService",
		"PracticeService",
		"ServerRoleService",
	},
	Priority = 600,
})

function PartyFunnelService:Setup()
	self.Waiting = {} :: { [Player]: { [number]: boolean } }
	self.Rounds = {} :: { [Player]: number }
	self.Counted = {} :: { [Player]: boolean }
	self.InMatch = false :: boolean
end

function PartyFunnelService:Step(player: Player, step: string, fields: { string }?)
	self.Dependencies.FunnelService:Step(player, "Party", step, fields)
end

function PartyFunnelService:OnAnswered(player: Player, from: number, result: string)
	if result ~= "Accepted" then
		self.Dependencies.FunnelService:Drop(player, "Party", result)
		return
	end

	local waiting = self.Waiting[player]
	if not waiting then
		waiting = {}
		self.Waiting[player] = waiting
	end
	waiting[from] = true
	self:Step(player, "InviteAccepted")
end

function PartyFunnelService:OnLobbyJoin(arrived: Player)
	for inviter, waiting in self.Waiting do
		if waiting[arrived.UserId] then
			waiting[arrived.UserId] = nil
			self:Step(inviter, "JoinedLeaderLobby")
		end
	end
end

function PartyFunnelService:Mates(player: Player): { Player }
	const mates: { Player } = {}
	const raw = self.Dependencies.ServerRoleService:GetRaw()
	const squads = if raw then raw.Squads else nil
	if typeof(squads) ~= "table" then
		return mates
	end

	for _, squad in squads do
		if typeof(squad) ~= "table" or not table.find(squad, player.UserId) then
			continue
		end
		for _, userId in squad do
			const mate = if typeof(userId) == "number" and userId ~= player.UserId
				then Players:GetPlayerByUserId(userId)
				else nil
			if mate then
				table.insert(mates, mate)
			end
		end
	end
	return mates
end

function PartyFunnelService:OnMatchJoin(player: Player)
	const mates = self:Mates(player)
	if not self.Counted[player] then
		self.Counted[player] = true
		self.Dependencies.FunnelService:Event(player, "MatchSquad", 1, { if #mates > 0 then "Party" else "Solo" })
	end

	if #mates == 0 then
		return
	end
	self:Step(player, "PlayedTogether")
	for _, mate in mates do
		self:Step(mate, "PlayedTogether")
	end
end

function PartyFunnelService:OnRoundStarted()
	for _, player in Players:GetPlayers() do
		if #self:Mates(player) == 0 then
			continue
		end

		const rounds = (self.Rounds[player] or 0) + 1
		self.Rounds[player] = rounds
		if rounds >= ROUNDS_GOAL then
			self:Step(player, "TogetherRound3")
		end
	end
end

function PartyFunnelService:Activate()
	const roles = self.Dependencies.ServerRoleService
	self.InMatch = roles:IsMatch() and not self.Dependencies.PracticeService:IsPractice()
	if not self.InMatch then
		return
	end

	task.defer(function()
		for _, player in Players:GetPlayers() do
			self:OnMatchJoin(player)
		end
	end)
end

function PartyFunnelService:Forget(player: Player)
	self.Waiting[player] = nil
	self.Rounds[player] = nil
	self.Counted[player] = nil
end

PartyFunnelService:OnInit(function(self)
	self:Setup()
end)

PartyFunnelService:OnStart(function(self)
	const invites = self.Dependencies.InviteService
	invites.Sent:Connect(function(player)
		self:Step(player, "Invited")
	end)

	invites.Answered:Connect(function(player, from, result)
		self:OnAnswered(player, from, result)
	end)

	self.Dependencies.ServerRoleService:OnReady(function()
		self:Activate()
	end)

	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
		if self.InMatch then
			task.defer(function()
				self:OnMatchJoin(player)
			end)
		else
			self:OnLobbyJoin(player)
		end
	end)

	self.Dependencies.MatchStatsService.MatchStarted:Connect(function()
		if self.InMatch then
			self:OnRoundStarted()
		end
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Forget(player)
	end)
end)

return PartyFunnelService
