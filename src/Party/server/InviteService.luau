--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PartyNet = require(ReplicatedStorage.shared.Party.Net)
local PartySettings = require(ReplicatedStorage.shared.Party.PartySettings)
local SquadRecord = require(ReplicatedStorage.shared.Party.SquadRecord)
local Modux = require(ServerScriptService.server.Modux)

type Incoming = {
	Id: string,
	From: number,
	FromName: string,
	Squad: string,
	Reply: string,
	Expires: number,
}

type Outgoing = {
	From: Player,
	To: number,
	Expires: number,
}

type Result = "Accepted" | "Declined" | "Expired" | "Unavailable" | "Failed"
type FriendCache = { Ids: { [number]: boolean }, Names: { [number]: string }, At: number }
type PresenceEntry = { Value: any, At: number }

const InviteService = Modux.Service("InviteService", {
	Require = {
		"NetService",
		"PlayerService",
		"PresenceService",
		"SquadService",
		"SquadStore",
		"MatchRegistryService",
		"TeleportGateway",
	},
	Priority = 820,
})

function InviteService:Setup()
	self.Friends = {} :: { [number]: FriendCache }
	self.PresenceCache = {} :: { [number]: PresenceEntry }
	self.Budget = {} :: { [Player]: { Start: number, Count: number } }
	self.LastFriends = {} :: { [Player]: number }
	self.LastEntries = {} :: { [Player]: { PartyNet.Friend } }
	self.LastInvite = {} :: { [Player]: number }
	self.Incoming = {} :: { [Player]: { Incoming } }
	self.Outgoing = {} :: { [string]: Outgoing }
	self.Joining = {} :: { [Player]: string }
end

function InviteService:Notice(player: Player, message: string)
	const netService = self.Dependencies.NetService
	if not netService:IsRunning() or not netService:IsReady(player) or not player:IsDescendantOf(Players) then
		return
	end

	self.Libs.Net.Party.Notice:fireClient(player, { Message = string.sub(message, 1, 200) })
end

function InviteService:Spend(player: Player): boolean
	const now = os.clock()
	local budget = self.Budget[player]
	if not budget or now - budget.Start >= 60 then
		budget = { Start = now, Count = 0 }
		self.Budget[player] = budget
	end

	if budget.Count >= PartySettings.ReadsPerMinute then
		return false
	end

	budget.Count += 1
	return true
end

function InviteService:ReadPresence(player: Player, userId: number): (any, boolean)
	const now = os.clock()
	const cached = self.PresenceCache[userId]
	if cached and now - cached.At < PartySettings.PresenceCacheTTL then
		return cached.Value, true
	end

	if not self:Spend(player) then
		return nil, false
	end

	const value, readable = self.Dependencies.PresenceService:Read(userId)
	if readable then
		self.PresenceCache[userId] = { Value = value, At = now }
	end
	return value, readable
end

function InviteService:PrunePresenceCache()
	const now = os.clock()
	for userId, entry in self.PresenceCache do
		if now - entry.At >= PartySettings.PresenceCacheTTL then
			self.PresenceCache[userId] = nil
		end
	end
end

function InviteService:LoadFriends(player: Player): FriendCache?
	const cached = self.Friends[player.UserId]
	if cached and os.clock() - cached.At < PartySettings.FriendsCacheTTL then
		return cached
	end

	const ok, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if not ok then
		warn(`[InviteService] GetFriendsAsync falhou para {player.Name}: {tostring(pages)}`)
		return nil
	end

	const ids: { [number]: boolean } = {}
	const names: { [number]: string } = {}
	for _ = 1, PartySettings.FriendsMaxPages do
		for _, item in pages:GetCurrentPage() do
			const entry = item :: any
			if typeof(entry.Id) == "number" then
				ids[entry.Id] = true
				const display = if typeof(entry.DisplayName) == "string" and entry.DisplayName ~= ""
					then entry.DisplayName
					else entry.Username
				if typeof(display) == "string" then
					names[entry.Id] = display
				end
			end
		end

		if pages.IsFinished then
			break
		end

		const advanced = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not advanced then
			break
		end
	end

	const loaded: FriendCache = { Ids = ids, Names = names, At = os.clock() }
	self.Friends[player.UserId] = loaded
	return loaded
end

function InviteService:IsFriend(player: Player, userId: number): boolean
	const friends = self:LoadFriends(player)
	if friends then
		return friends.Ids[userId] == true
	end

	const ok, result = pcall(function()
		return player:IsFriendsWithAsync(userId)
	end)
	return ok and result == true
end

function InviteService:NameOf(owner: Player, userId: number): string
	const player = Players:GetPlayerByUserId(userId)
	if player then
		return player.DisplayName
	end

	const friends = self.Friends[owner.UserId]
	const name = if friends then friends.Names[userId] else nil
	return name or tostring(userId)
end

function InviteService:ListFriends(player: Player, candidates: { number }): { PartyNet.Friend }
	const entries: { PartyNet.Friend } = {}
	const squad = self.Dependencies.SquadService
	if not squad:IsLobbyActive() then
		return entries
	end

	const now = os.clock()
	if now - (self.LastFriends[player] or 0) < PartySettings.FriendsCooldown then
		return self.LastEntries[player] or entries
	end
	self.LastFriends[player] = now

	const unique: { number } = {}
	for _, userId in candidates do
		if
			userId ~= player.UserId
			and userId == math.floor(userId)
			and userId > 0
			and not table.find(unique, userId)
			and #unique < PartySettings.MaxCandidates
		then
			table.insert(unique, userId)
		end
	end

	const key = squad:GetKey()
	self:PrunePresenceCache()
	for _, userId in unique do
		if not self:IsFriend(player, userId) then
			continue
		end

		const current = self:ReadPresence(player, userId)
		if not current then
			continue
		end

		table.insert(entries, {
			UserId = userId,
			Name = string.sub(self:NameOf(player, userId), 1, 40),
			Location = current.Role,
			InSquad = current.Squad == key or squad:IsMember(userId),
		})
	end

	self.LastEntries[player] = entries
	return entries
end

function InviteService:Validate(player: Player, userId: number): string?
	const squad = self.Dependencies.SquadService
	if not squad:IsLobbyActive() then
		return "You can only invite from the lobby"
	end

	if squad:IsLocal() then
		return "Squad invites only work in the published game"
	end

	if userId == player.UserId or userId <= 0 then
		return "Invalid player"
	end

	if squad:IsMember(userId) then
		return "This player is already in your squad"
	end

	if not squad:HasRoom() then
		return "Your squad is full"
	end

	if os.clock() - (self.LastInvite[player] or 0) < PartySettings.InviteCooldown then
		return "Wait a moment before inviting again"
	end

	const now = os.time()
	for _, outgoing in self.Outgoing do
		if outgoing.From == player and outgoing.To == userId and outgoing.Expires > now then
			return "Invite already sent"
		end
	end

	return nil
end

function InviteService:Invite(player: Player, userId: number): (boolean, string)
	const problem = self:Validate(player, userId)
	if problem then
		return false, problem
	end
	self.LastInvite[player] = os.clock()

	if not self:IsFriend(player, userId) then
		return false, "You can only invite friends"
	end

	const presence = self.Dependencies.PresenceService
	if not self:Spend(player) then
		return false, "Wait a moment before inviting again"
	end

	const target = presence:Read(userId)
	if not target then
		return false, "This player is not in the game"
	end

	const key = self.Dependencies.SquadService:GetKey()
	if target.Squad == key then
		return false, "This player is already in your squad"
	end

	const id = HttpService:GenerateGUID(false)
	const expires = os.time() + PartySettings.InviteDuration
	const sent = presence:Send(target.Job, {
		K = "Invite",
		Id = id,
		From = player.UserId,
		FromName = string.sub(player.DisplayName, 1, 40),
		To = userId,
		Squad = key,
		Reply = presence.JobId,
		Exp = expires,
	})
	if not sent then
		return false, "Could not reach this player, try again"
	end

	self.Outgoing[id] = { From = player, To = userId, Expires = expires }
	task.delay(PartySettings.InviteDuration + 5, function()
		self.Outgoing[id] = nil
	end)

	return true, ""
end

function InviteService:Reply(invite: Incoming, from: Player, result: Result, reason: string?)
	self.Dependencies.PresenceService:Send(invite.Reply, {
		K = "Reply",
		Id = invite.Id,
		From = from.UserId,
		FromName = string.sub(from.DisplayName, 1, 40),
		To = invite.From,
		Result = result,
		Reason = string.sub(reason or "", 1, 120),
	})
end

function InviteService:Take(player: Player, id: string): Incoming?
	const list = self.Incoming[player]
	if not list then
		return nil
	end

	for index, invite in list do
		if invite.Id == id then
			table.remove(list, index)
			return invite
		end
	end
	return nil
end

function InviteService:Deliver(message: { [string]: any })
	const to = message.To
	const player = if typeof(to) == "number" then Players:GetPlayerByUserId(to) else nil
	const invite: Incoming = {
		Id = tostring(message.Id),
		From = if typeof(message.From) == "number" then message.From else 0,
		FromName = if typeof(message.FromName) == "string" then message.FromName else "",
		Squad = if typeof(message.Squad) == "string" then message.Squad else "",
		Reply = if typeof(message.Reply) == "string" then message.Reply else "",
		Expires = if typeof(message.Exp) == "number" then message.Exp else 0,
	}

	if invite.From == 0 or invite.Squad == "" or invite.Reply == "" then
		return
	end

	const remaining = invite.Expires - os.time()
	if not player or remaining <= 0 then
		self.Dependencies.PresenceService:Send(invite.Reply, {
			K = "Reply",
			Id = invite.Id,
			From = if typeof(to) == "number" then to else 0,
			FromName = "",
			To = invite.From,
			Result = "Unavailable",
			Reason = "",
		})
		return
	end

	const list = self.Incoming[player] or {}
	self.Incoming[player] = list
	for index, existing in list do
		if existing.From == invite.From then
			table.remove(list, index)
			break
		end
	end
	table.insert(list, invite)

	const netService = self.Dependencies.NetService
	if netService:IsRunning() and netService:IsReady(player) then
		self.Libs.Net.Party.Invited:fireClient(player, {
			Id = invite.Id,
			From = invite.From,
			FromName = invite.FromName,
			Seconds = math.clamp(remaining, 0, 120),
		})
	end

	task.delay(remaining + 1, function()
		if self:Take(player, invite.Id) then
			self:Reply(invite, player, "Expired", nil)
		end
	end)
end

function InviteService:HandleReply(message: { [string]: any })
	const to = message.To
	const player = if typeof(to) == "number" then Players:GetPlayerByUserId(to) else nil
	if typeof(message.Id) == "string" then
		self.Outgoing[message.Id] = nil
	end
	if not player then
		return
	end

	const from = if typeof(message.From) == "number" then message.From else 0
	const netService = self.Dependencies.NetService
	if from ~= 0 and netService:IsRunning() and netService:IsReady(player) then
		self.Libs.Net.Party.Resolved:fireClient(player, { UserId = from })
	end

	const name = if typeof(message.FromName) == "string" and message.FromName ~= "" then message.FromName else "Your friend"
	const result = message.Result
	if result == "Declined" then
		self:Notice(player, `{name} declined your invite`)
	elseif result == "Expired" then
		self:Notice(player, `{name} did not answer your invite`)
	elseif result == "Unavailable" then
		self:Notice(player, "Your friend is no longer available")
	elseif result == "Failed" then
		const reason = if typeof(message.Reason) == "string" and message.Reason ~= "" then message.Reason else "unknown error"
		self:Notice(player, `{name} could not join: {reason}`)
	end
end

function InviteService:UndoJoin(player: Player)
	const key = self.Joining[player]
	self.Joining[player] = nil
	self.Dependencies.SquadService:SetDeparting(player, false)
	if key then
		task.spawn(function()
			self.Dependencies.SquadStore:RemoveMember(key, player.UserId)
		end)
	end
end

function InviteService:JoinLobby(player: Player, key: string): (boolean, string?)
	const lobby = self.Dependencies.MatchRegistryService:FindLobby(key)
	if not lobby then
		self.Joining[player] = nil
		task.spawn(function()
			self.Dependencies.SquadStore:RemoveMember(key, player.UserId)
		end)
		return false, "The squad lobby is no longer available"
	end

	self.Joining[player] = key
	self.Dependencies.SquadService:SetDeparting(player, true)

	const teleported, reason = self.Dependencies.TeleportGateway:Teleport({ player }, lobby.AccessCode, {
		ReturnLobby = key,
	})
	if not teleported then
		self:UndoJoin(player)
		return false, reason or "Failed to join the squad lobby"
	end
	return true, nil
end

function InviteService:Join(player: Player, key: string): (boolean, string?)
	const squad = self.Dependencies.SquadService
	if key == "" then
		return false, "Invalid squad"
	end

	if squad:IsLocal() then
		return false, "Squads are unavailable on this server"
	end

	const previous = squad:CurrentKey(player)
	if previous == key then
		return false, "You are already in this squad"
	end

	if self.Joining[player] then
		return false, "You are already joining a squad"
	end
	self.Joining[player] = key

	const inLobby = squad:IsLobbyActive()
	const result, record = self.Dependencies.SquadStore:AddMember(key, player, if inLobby then "Lobby" else "Idle")
	if result ~= "Ok" or not record then
		self.Joining[player] = nil
		if result == "Error" then
			return false, "Squad service unavailable, try again"
		elseif result == "Full" then
			return false, "This squad is full"
		end
		return false, "This squad no longer exists"
	end

	self.Dependencies.SquadStore:GrantToken(key, player.UserId)

	if inLobby then
		return self:JoinLobby(player, key)
	end

	self.Joining[player] = nil

	squad:SetReturnKey(player, key)
	if previous then
		task.spawn(function()
			self.Dependencies.SquadStore:RemoveMember(previous, player.UserId)
		end)
	end

	self:Notice(
		player,
		`You joined {SquadRecord.leaderName(record)}'s squad. You will go to their lobby when you leave this match.`
	)
	return true, nil
end

function InviteService:Respond(player: Player, id: string, accept: boolean)
	const invite = self:Take(player, id)
	if not invite then
		return
	end

	if invite.Expires < os.time() then
		self:Notice(player, "This invite has expired")
		self:Reply(invite, player, "Expired", nil)
		return
	end

	if not accept then
		self:Reply(invite, player, "Declined", nil)
		return
	end

	const joined, reason = self:Join(player, invite.Squad)
	if joined then
		self:Reply(invite, player, "Accepted", nil)
		return
	end

	self:Notice(player, reason or "Could not join the squad")
	self:Reply(invite, player, "Failed", reason)
end

function InviteService:OnMessage(message: { [string]: any })
	if message.K == "Invite" then
		self:Deliver(message)
	elseif message.K == "Reply" then
		self:HandleReply(message)
	end
end

InviteService:OnInit(function(self)
	self:Setup()

	const net = self.Libs.Net.Party

	net.Friends:onServer(function(request, player)
		return { Entries = self:ListFriends(player, request.Candidates) }
	end)

	net.Invite:onServer(function(request, player)
		const accepted, reason = self:Invite(player, request.UserId)
		return { Accepted = accepted, Reason = reason }
	end)

	net.Respond:onServer(function(request, player)
		task.spawn(function()
			self:Respond(player, request.Id, request.Accept)
		end)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.LastFriends[player] = nil
		self.LastEntries[player] = nil
		self.Budget[player] = nil
		self.LastInvite[player] = nil
		self.Joining[player] = nil
		self.Incoming[player] = nil
		self.Friends[player.UserId] = nil
		for id, outgoing in self.Outgoing do
			if outgoing.From == player then
				self.Outgoing[id] = nil
			end
		end
	end)
end)

InviteService:OnStart(function(self)
	self.Dependencies.PresenceService.Message:Connect(function(message)
		task.spawn(function()
			self:OnMessage(message)
		end)
	end)

	self.Dependencies.SquadService.Notify:Connect(function(player, message)
		self:Notice(player, message)
	end)

	self.Dependencies.TeleportGateway.Failed:Connect(function(player, reason)
		if self.Joining[player] then
			self:UndoJoin(player)
			self:Notice(player, `Could not join the squad: {reason}`)
		end
	end)

	self.Dependencies.NetService.ClientReady:Connect(function(player)
		const list = self.Incoming[player]
		if not list then
			return
		end

		const now = os.time()
		for _, invite in list do
			const remaining = invite.Expires - now
			if remaining > 0 then
				self.Libs.Net.Party.Invited:fireClient(player, {
					Id = invite.Id,
					From = invite.From,
					FromName = invite.FromName,
					Seconds = math.clamp(remaining, 0, 120),
				})
			end
		end
	end)
end)

return InviteService
