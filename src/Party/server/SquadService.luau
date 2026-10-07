--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MatchmakingSettings = require(ReplicatedStorage.shared.Matchmaking.MatchmakingSettings)
local PartyNet = require(ReplicatedStorage.shared.Party.Net)
local PartySettings = require(ReplicatedStorage.shared.Party.PartySettings)
local SquadRecord = require(ReplicatedStorage.shared.Party.SquadRecord)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

type Record = SquadRecord.Record
type Snapshot = { Leader: number, Members: { PartyNet.Member } }
type Inputs = {
	Key: string,
	Job: string,
	Owner: number?,
	Present: { Player },
	Removals: { [number]: boolean },
	Prune: { [number]: boolean },
	Allowed: { [number]: boolean },
	Strict: boolean,
}

const SquadService = Modux.Service("SquadService", {
	Require = {
		"NetService",
		"PlayerService",
		"ServerRoleService",
		"MatchRegistryService",
		"TeleportGateway",
		"PresenceService",
		"SpawnService",
		"SquadStore",
	},
	Priority = 830,
})

local function compose(previous: Record?, inputs: Inputs): (Record, { Player }, { Player })
	const now = os.time()
	const record: Record = {
		Leader = if previous then previous.Leader else 0,
		Lobby = inputs.Key,
		Job = inputs.Job,
		Members = {},
		At = now,
	}

	const presentById: { [number]: Player } = {}
	for _, player in inputs.Present do
		presentById[player.UserId] = player
	end

	if previous then
		for _, member in previous.Members do
			if inputs.Removals[member.Id] or inputs.Prune[member.Id] then
				continue
			end

			const copy = table.clone(member)
			const player = presentById[member.Id]
			if player then
				copy.Status = "Lobby"
				copy.Name = string.sub(player.DisplayName, 1, 40)
			end
			table.insert(record.Members, copy)
		end
	end

	const overflow: { Player } = {}
	const rejected: { Player } = {}
	for _, player in inputs.Present do
		if SquadRecord.find(record, player.UserId) then
			continue
		end

		if inputs.Strict and not inputs.Allowed[player.UserId] then
			table.insert(rejected, player)
			continue
		end

		if #record.Members >= PartySettings.MaxSize then
			table.insert(overflow, player)
			continue
		end

		const member: SquadRecord.Member = {
			Id = player.UserId,
			Name = string.sub(player.DisplayName, 1, 40),
			Status = "Lobby",
			Joined = now,
		}
		table.insert(record.Members, member)
	end

	const preferred: { number } = {}
	if inputs.Owner and presentById[inputs.Owner] then
		table.insert(preferred, inputs.Owner)
	end
	for _, member in record.Members do
		if presentById[member.Id] then
			table.insert(preferred, member.Id)
		end
	end
	SquadRecord.promote(record, preferred)

	return record, overflow, rejected
end

local function snapshot(record: Record?): Snapshot
	const members: { PartyNet.Member } = {}
	if not record then
		return { Leader = 0, Members = members }
	end

	const now = os.time()
	for index, member in SquadRecord.ordered(record) do
		table.insert(members, {
			UserId = member.Id,
			Name = member.Name,
			Slot = index,
			Status = SquadRecord.display(member, Players:GetPlayerByUserId(member.Id) ~= nil, now),
		})
	end
	return { Leader = record.Leader, Members = members }
end

local function readReturnLobby(player: Player): string?
	const ok, joinData = pcall(function(): any
		return player:GetJoinData()
	end)
	if not ok or typeof(joinData) ~= "table" or joinData.SourcePlaceId ~= game.PlaceId then
		return nil
	end

	const data: any = joinData.TeleportData
	if typeof(data) == "table" and typeof(data.ReturnLobby) == "string" and data.ReturnLobby ~= "" then
		return data.ReturnLobby
	end
	return nil
end

function SquadService:Setup()
	self.Key = "" :: string
	self.Local = true :: boolean
	self.LobbyActive = false :: boolean
	self.MatchActive = false :: boolean
	self.Record = nil :: Record?
	self.Removals = {} :: { [number]: boolean }
	self.Departing = {} :: { [number]: boolean }
	self.Traveling = {} :: { [number]: number }
	self.Relocating = {} :: { [Player]: boolean }
	self.Misses = {} :: { [number]: number }
	self.Admitted = {} :: { [number]: boolean }
	self.Checked = {} :: { [number]: boolean }
	self.ReturnKeys = {} :: { [Player]: string }
	self.Syncing = false :: boolean
	self.SyncQueued = false :: boolean
	self.Changed = self.Libs.Signal.new() :: SignalLib.Signal<>
	self.Notify = self.Libs.Signal.new() :: SignalLib.Signal<Player, string>
end

function SquadService:GetKey(): string
	return self.Key
end

function SquadService:GetRecord(): Record?
	return self.Record
end

function SquadService:IsLobbyActive(): boolean
	return self.LobbyActive
end

function SquadService:IsLocal(): boolean
	return self.Local
end

function SquadService:IsMember(userId: number): boolean
	const record = self.Record
	return record ~= nil and SquadRecord.find(record, userId) ~= nil
end

function SquadService:HasRoom(): boolean
	const record = self.Record
	return record == nil or #record.Members < PartySettings.MaxSize
end

function SquadService:GetLeader(): Player?
	const record = self.Record
	if not record or record.Leader == 0 then
		return nil
	end
	return Players:GetPlayerByUserId(record.Leader)
end

function SquadService:PresentMembers(): { Player }
	const present: { Player } = {}
	const record = self.Record
	if not record then
		return present
	end

	for _, member in SquadRecord.ordered(record) do
		const player = Players:GetPlayerByUserId(member.Id)
		if player and not self.Departing[member.Id] then
			table.insert(present, player)
		end
	end
	return present
end

function SquadService:PlayBlocker(): string?
	const record = self.Record
	if not record then
		return nil
	end

	for _, member in record.Members do
		if Players:GetPlayerByUserId(member.Id) == nil then
			return "Waiting for squad members"
		end
	end
	return nil
end

function SquadService:MarkTraveling(players: { Player }, traveling: boolean)
	for _, player in players do
		self.Traveling[player.UserId] = if traveling then os.clock() else nil
	end
end

function SquadService:AnyTraveling(): boolean
	const now = os.clock()
	for userId, since in self.Traveling do
		if now - since > MatchmakingSettings.SearchTimeout then
			self.Traveling[userId] = nil
		elseif Players:GetPlayerByUserId(userId) == nil or self:IsMember(userId) then
			return true
		end
	end
	return false
end

function SquadService:SetDeparting(player: Player, departing: boolean)
	const userId = player.UserId
	self.Departing[userId] = if departing then true else nil
	self.Removals[userId] = if departing then true else nil
	self:RequestSync()
end

function SquadService:CurrentKey(player: Player): string?
	if self.LobbyActive then
		return self.Key
	end
	return self.ReturnKeys[player]
end

function SquadService:SetReturnKey(player: Player, key: string)
	self.ReturnKeys[player] = key
	self.Dependencies.PresenceService:SetSquad(player, key)
end

function SquadService:GetReturnKey(player: Player): string?
	return self.ReturnKeys[player]
end

function SquadService:Remove(key: string, userId: number)
	if self.LobbyActive and key == self.Key then
		self.Removals[userId] = true
		self:RequestSync()
	elseif not self.Local then
		self.Dependencies.SquadStore:RemoveMember(key, userId)
	end
end

function SquadService:CheckAbsent(): { [number]: boolean }
	const prune: { [number]: boolean } = {}
	const record = self.Record
	if not record then
		return prune
	end

	const now = os.time()
	const presence = self.Dependencies.PresenceService
	for _, member in record.Members do
		if Players:GetPlayerByUserId(member.Id) or now - member.Joined < PartySettings.JoinGrace then
			self.Misses[member.Id] = nil
			continue
		end

		const current, readable = presence:Read(member.Id)
		if not readable then
			continue
		end

		if current and current.Squad == self.Key then
			self.Misses[member.Id] = nil
			continue
		end

		const firstMiss = self.Misses[member.Id]
		if not firstMiss then
			self.Misses[member.Id] = now
		elseif now - firstMiss >= PartySettings.PruneAfter then
			self.Misses[member.Id] = nil
			prune[member.Id] = true
		end
	end
	return prune
end

function SquadService:Sync()
	if not self.LobbyActive then
		return
	end

	const removals = table.clone(self.Removals)
	const present: { Player } = {}
	for _, player in Players:GetPlayers() do
		if not self.Departing[player.UserId] and not self.Relocating[player] then
			table.insert(present, player)
		end
	end

	const owner = self.Dependencies.MatchRegistryService:GetOwner()
	const allowed: { [number]: boolean } = {}
	if owner then
		allowed[owner] = true
	end

	for _, player in present do
		const userId = player.UserId
		if self:IsMember(userId) then
			self.Admitted[userId] = true
		end

		if self.Admitted[userId] then
			allowed[userId] = true
		elseif not self.Local and not self.Checked[userId] then
			self.Checked[userId] = true
			if self.Dependencies.SquadStore:HasToken(self.Key, userId) then
				self.Admitted[userId] = true
				allowed[userId] = true
			end
		end
	end

	const inputs: Inputs = {
		Key = self.Key,
		Job = self.Dependencies.PresenceService.JobId,
		Owner = owner,
		Present = present,
		Removals = removals,
		Prune = self:CheckAbsent(),
		Allowed = allowed,
		Strict = not self.Local,
	}

	local record: Record? = nil
	local overflow: { Player } = {}
	local rejected: { Player } = {}
	local stored = false

	if not self.Local then
		const ok, written = self.Dependencies.SquadStore:Update(self.Key, function(current: Record?): Record?
			const composed, extra, refused = compose(current, inputs)
			overflow = extra
			rejected = refused
			return composed
		end)
		if ok then
			record = written
			stored = true
		end
	end

	if not record then
		record, overflow, rejected = compose(self.Record, inputs)
	end

	for userId in removals do
		self.Removals[userId] = nil
	end

	self.Record = record

	if stored or self.Local then
		for _, player in overflow do
			self:Relocate(player, "This squad is full, moving you to your own lobby")
		end
		for _, player in rejected do
			self:Relocate(player, "You are not in this squad, moving you to your own lobby")
		end
	end

	for _, player in present do
		const member = record ~= nil and SquadRecord.find(record, player.UserId) ~= nil
		if member then
			self.Admitted[player.UserId] = true
		end
		self.Dependencies.PresenceService:SetSquad(player, if member then self.Key else "")
	end

	self:Publish(nil)
	self:Arrange()
	self.Changed:Fire()
end

function SquadService:RequestSync()
	if not self.LobbyActive then
		return
	end

	if self.Syncing then
		self.SyncQueued = true
		return
	end

	self.Syncing = true
	task.spawn(function()
		repeat
			self.SyncQueued = false
			const ok, reason = pcall(function()
				self:Sync()
			end)
			if not ok then
				warn(`[SquadService] falha ao sincronizar o squad: {tostring(reason)}`)
			end
		until not self.SyncQueued
		self.Syncing = false
	end)
end

function SquadService:Publish(target: Player?)
	const netService = self.Dependencies.NetService
	if not netService:IsRunning() then
		return
	end

	const state = snapshot(self.Record)
	const empty = snapshot(nil)
	const recipients = if target then { target } else Players:GetPlayers()
	for _, player in recipients do
		if netService:IsReady(player) then
			self.Libs.Net.Party.State:fireClient(player, if self:IsMember(player.UserId) then state else empty)
		end
	end
end

function SquadService:Arrange()
	const record = self.Record
	if not record then
		return
	end

	const assignments: { [Player]: number } = {}
	for _, player in self:PresentMembers() do
		const slot = SquadRecord.slot(record, player.UserId)
		if slot then
			assignments[player] = slot
		end
	end
	self.Dependencies.SpawnService:ArrangeSlots(assignments)
end

function SquadService:Relocate(player: Player, message: string)
	if self.Relocating[player] or self.Dependencies.TeleportGateway:IsSimulated() then
		return
	end
	self.Relocating[player] = true
	self.Notify:Fire(player, message)

	task.spawn(function()
		const target, failure = self.Dependencies.MatchRegistryService:CreateLobby(player.UserId)
		local teleported = false
		local reason = failure
		if target then
			teleported, reason = self.Dependencies.TeleportGateway:Teleport({ player }, target.AccessCode, {
				ReturnLobby = target.Key,
			})
		end
		if not teleported then
			warn(`[SquadService] falha ao realocar {player.Name}: {tostring(reason)}`)
			self.Relocating[player] = nil
		end
	end)
end

function SquadService:Renew()
	const keys: { string } = {}
	for _, key in self.ReturnKeys do
		if not table.find(keys, key) then
			table.insert(keys, key)
		end
	end

	const registry = self.Dependencies.MatchRegistryService
	for _, key in keys do
		self.Dependencies.SquadStore:Touch(key)
		registry:UpdateConfig(key, function(lobby: any): any
			if typeof(lobby) ~= "table" or lobby.Kind ~= "Lobby" then
				return nil
			end
			return lobby
		end, MatchmakingSettings.LobbyConfigTTL)
	end
end

function SquadService:ActivateLobby()
	const key = self.Dependencies.MatchRegistryService:GetLobbyKey()
	self.Key = key or "studio"
	self.Local = key == nil
	self.LobbyActive = true

	self.Dependencies.SpawnService.SlotProvider = function(player: Player): number?
		const record = self.Record
		return if record then SquadRecord.slot(record, player.UserId) else nil
	end

	const onAdded = function(player: Player)
		self.Removals[player.UserId] = nil
		self.Traveling[player.UserId] = nil
		self:RequestSync()
	end

	for _, player in Players:GetPlayers() do
		onAdded(player)
	end

	self.Dependencies.PlayerService.PlayerAdded:Connect(onAdded)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		const userId = player.UserId
		self.Relocating[player] = nil
		if self.Traveling[userId] then
			self.Traveling[userId] = nil
		else
			self.Removals[userId] = true
		end
		self.Departing[userId] = nil
		self.Misses[userId] = nil
		self.Checked[userId] = nil

		task.defer(function()
			self:RequestSync()
		end)
	end)

	task.spawn(function()
		while self.LobbyActive do
			task.wait(PartySettings.SyncInterval)
			self:RequestSync()
		end
	end)
end

function SquadService:ActivateMatch()
	self.MatchActive = true
	self.Local = game.PrivateServerId == ""

	const onAdded = function(player: Player)
		const key = readReturnLobby(player)
		if not key then
			return
		end

		if self.Local then
			self:SetReturnKey(player, key)
			return
		end

		task.spawn(function()
			for attempt = 1, PartySettings.StoreAttempts do
				const readable, record = self.Dependencies.SquadStore:Get(key)
				if not player:IsDescendantOf(Players) or self.ReturnKeys[player] ~= nil then
					return
				end

				if readable and not (record and SquadRecord.find(record, player.UserId)) then
					return
				end

				if readable then
					self:SetReturnKey(player, key)
					return
				end

				task.wait(PartySettings.StoreBackoff * 2 ^ attempt)
			end
		end)
	end

	for _, player in Players:GetPlayers() do
		onAdded(player)
	end

	self.Dependencies.PlayerService.PlayerAdded:Connect(onAdded)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.ReturnKeys[player] = nil
	end)

	if self.Local then
		return
	end

	task.spawn(function()
		while self.MatchActive do
			task.wait(PartySettings.RenewInterval)
			self:Renew()
		end
	end)
end

SquadService:OnInit(function(self)
	self:Setup()
end)

SquadService:OnStart(function(self)
	const roleService = self.Dependencies.ServerRoleService
	roleService:OnReady(function()
		if roleService:IsLobby() then
			self:ActivateLobby()
		elseif roleService:IsMatch() then
			self:ActivateMatch()
		end
	end)

	self.Dependencies.PresenceService.Message:Connect(function(message)
		if message.K == "Squad" and self.LobbyActive and message.Squad == self.Key then
			self:RequestSync()
		end
	end)

	self.Dependencies.NetService.ClientReady:Connect(function(player)
		if self.LobbyActive then
			self:Publish(player)
		end
	end)

	self.Dependencies.TeleportGateway.Failed:Connect(function(player)
		self.Relocating[player] = nil
	end)
end)

return SquadService
