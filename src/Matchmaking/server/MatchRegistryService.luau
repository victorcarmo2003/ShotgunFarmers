--!strict
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GameModes = require(ReplicatedStorage.shared.Match.GameModes)
local MatchmakingSettings = require(ReplicatedStorage.shared.Matchmaking.MatchmakingSettings)
local Modux = require(ServerScriptService.server.Modux)

export type Entry = {
	AccessCode: string,
	Map: string,
	Mode: string,
	Players: number,
	Reserved: number,
	MaxPlayers: number,
	JoinInProgress: boolean,
	Private: boolean,
	UpdatedAt: number,
	Pending: { [string]: number },
}

export type Lobby = { Key: string, AccessCode: string, Players: number, Owner: number? }
export type Target = { Key: string, AccessCode: string }

const MatchRegistryService = Modux.Service("MatchRegistryService", {
	Require = { "PlayerService", "ServerRoleService", "RoundService", "TeleportGateway" },
	Priority = 895,
})

local function countPending(pending: { [string]: number }, now: number): number
	local total = 0
	for _, expires in pending do
		if expires > now then
			total += 1
		end
	end
	return total
end

local function sanitizeEntry(raw: any): Entry?
	if typeof(raw) ~= "table" or typeof(raw.AccessCode) ~= "string" or typeof(raw.Mode) ~= "string" then
		return nil
	end

	const pending: { [string]: number } = {}
	if typeof(raw.Pending) == "table" then
		for userId, expires in raw.Pending do
			if typeof(userId) == "string" and typeof(expires) == "number" then
				pending[userId] = expires
			end
		end
	end

	return {
		AccessCode = raw.AccessCode,
		Map = if typeof(raw.Map) == "string" then raw.Map else "",
		Mode = raw.Mode,
		Players = if typeof(raw.Players) == "number" then raw.Players else 0,
		Reserved = countPending(pending, os.time()),
		MaxPlayers = if typeof(raw.MaxPlayers) == "number" then raw.MaxPlayers else GameModes.GetMaxPlayers(raw.Mode),
		JoinInProgress = raw.JoinInProgress == true,
		Private = raw.Private == true,
		UpdatedAt = if typeof(raw.UpdatedAt) == "number" then raw.UpdatedAt else 0,
		Pending = pending,
	}
end

function MatchRegistryService:Setup()
	self.ConfigMap = nil :: MemoryStoreHashMap?
	self.Registry = nil :: MemoryStoreSortedMap?
	self.Key = game.PrivateServerId :: string
	self.Running = false :: boolean
	self.Beating = false :: boolean
	self.Queued = false :: boolean
	self.LastConfigRefresh = 0 :: number
	self.WarnedReasons = {} :: { [string]: boolean }
end

function MatchRegistryService:WarnOnce(label: string, reason: any)
	if self.WarnedReasons[label] then
		return
	end

	self.WarnedReasons[label] = true
	warn(`[MatchRegistryService] {label}: {tostring(reason)}`)
end

function MatchRegistryService:GetConfigMap(): MemoryStoreHashMap
	if not self.ConfigMap then
		self.ConfigMap = MemoryStoreService:GetHashMap(MatchmakingSettings.ConfigMapName)
	end

	return self.ConfigMap :: MemoryStoreHashMap
end

function MatchRegistryService:GetRegistry(): MemoryStoreSortedMap
	if not self.Registry then
		self.Registry = MemoryStoreService:GetSortedMap(MatchmakingSettings.RegistryMapName)
	end

	return self.Registry :: MemoryStoreSortedMap
end

function MatchRegistryService:IsSimulated(): boolean
	return self.Dependencies.TeleportGateway:IsSimulated()
end

function MatchRegistryService:Attempt(
	callback: () -> any,
	attempts: number?,
	backoff: number?,
	maxBackoff: number?
): (boolean, any)
	const total = attempts or MatchmakingSettings.StoreAttempts
	const base = backoff or MatchmakingSettings.StoreBackoff
	local lastError: any = nil
	for attempt = 1, total do
		const ok, result = pcall(callback)
		if ok then
			return true, result
		end

		lastError = result
		if attempt < total then
			const delay = base * 2 ^ (attempt - 1)
			task.wait(if maxBackoff then math.min(delay, maxBackoff) else delay)
		end
	end

	return false, lastError
end

function MatchRegistryService:FetchConfig(key: string, boot: boolean?): any?
	if key == "" or self:IsSimulated() then
		return nil
	end

	const ok, result = self:Attempt(
		function()
			return self:GetConfigMap():GetAsync(key)
		end,
		if boot then MatchmakingSettings.BootFetchAttempts else nil,
		if boot then MatchmakingSettings.BootFetchBackoff else nil,
		if boot then MatchmakingSettings.BootFetchBackoffMax else nil
	)
	if not ok then
		error(tostring(result))
	end

	return result
end

function MatchRegistryService:SetConfig(key: string, config: { [string]: any }, ttl: number): (boolean, string?)
	if self:IsSimulated() then
		return true, nil
	end

	const ok, reason = self:Attempt(function()
		return self:GetConfigMap():SetAsync(key, config, ttl)
	end)
	return ok, if ok then nil else tostring(reason)
end

function MatchRegistryService:UpdateConfig(key: string, transform: (any) -> any, ttl: number): boolean
	if self:IsSimulated() then
		return true
	end

	const ok, reason = self:Attempt(function()
		return self:GetConfigMap():UpdateAsync(key, transform, ttl)
	end)
	if not ok then
		self:WarnOnce("UpdateConfig", reason)
	end
	return ok
end

function MatchRegistryService:FindLobby(key: string): Lobby?
	if key == "" or self:IsSimulated() then
		return nil
	end

	const ok, raw = pcall(function()
		return self:FetchConfig(key)
	end)
	if not ok or typeof(raw) ~= "table" or raw.Kind ~= "Lobby" or typeof(raw.AccessCode) ~= "string" then
		return nil
	end

	return {
		Key = key,
		AccessCode = raw.AccessCode,
		Players = if typeof(raw.Players) == "number" then raw.Players else 0,
		Owner = if typeof(raw.Owner) == "number" then raw.Owner else nil,
	}
end

function MatchRegistryService:CreateLobby(ownerId: number): (Target?, string?)
	const reservation, reason = self.Dependencies.TeleportGateway:Reserve()
	if not reservation then
		return nil, reason
	end

	if self:IsSimulated() then
		return { Key = reservation.ServerId, AccessCode = reservation.AccessCode }, nil
	end

	const saved, saveReason = self:SetConfig(reservation.ServerId, {
		Kind = "Lobby",
		Owner = ownerId,
		AccessCode = reservation.AccessCode,
		Created = os.time(),
		Players = 0,
	}, MatchmakingSettings.LobbyConfigTTL)
	if not saved then
		return nil, `Falha ao registrar lobby: {saveReason}`
	end

	return { Key = reservation.ServerId, AccessCode = reservation.AccessCode }, nil
end

function MatchRegistryService:GetLobbyKey(): string?
	const raw = self.Dependencies.ServerRoleService:GetRaw()
	if self.Key == "" or not raw or raw.Kind ~= "Lobby" then
		return nil
	end
	return self.Key
end

function MatchRegistryService:GetOwner(): number?
	const raw = self.Dependencies.ServerRoleService:GetRaw()
	if raw and typeof(raw.Owner) == "number" then
		return raw.Owner
	end
	return nil
end

function MatchRegistryService:ListMatches(): { [string]: Entry }
	const entries: { [string]: Entry } = {}
	if self:IsSimulated() then
		return entries
	end

	local lowerBound: string? = nil

	for _ = 1, MatchmakingSettings.RegistryMaxPages do
		const ok, items = self:Attempt(function()
			return self:GetRegistry()
				:GetRangeAsync(Enum.SortDirection.Ascending, MatchmakingSettings.RegistryPageSize, lowerBound)
		end)
		if not ok then
			self:WarnOnce("ListMatches", items)
			break
		end

		for _, item in items do
			const entry = sanitizeEntry(item.value)
			if entry then
				entries[item.key] = entry
			end
		end

		if #items < MatchmakingSettings.RegistryPageSize then
			break
		end

		lowerBound = items[#items].key
	end

	return entries
end

function MatchRegistryService:HasRoom(entry: Entry, size: number, now: number): boolean
	return not entry.Private
		and entry.JoinInProgress
		and now - entry.UpdatedAt <= MatchmakingSettings.RegistryTTL
		and entry.Players + countPending(entry.Pending, now) + size <= entry.MaxPlayers
end

function MatchRegistryService:ReserveSlots(key: string, userIds: { number }): boolean
	if self:IsSimulated() then
		return false
	end

	local reserved = false
	const ok = pcall(function()
		self:GetRegistry():UpdateAsync(key, function(raw: any): any
			reserved = false
			const entry = sanitizeEntry(raw)
			const now = os.time()
			if not entry or not self:HasRoom(entry, #userIds, now) then
				return nil
			end

			for userId, expires in entry.Pending do
				if expires <= now then
					entry.Pending[userId] = nil
				end
			end
			for _, userId in userIds do
				entry.Pending[tostring(userId)] = now + MatchmakingSettings.ReservationTTL
			end
			entry.Reserved = countPending(entry.Pending, now)
			reserved = true
			return entry
		end, MatchmakingSettings.RegistryTTL)
	end)

	return ok and reserved
end

function MatchRegistryService:ReleaseSlots(key: string, userIds: { number })
	if self:IsSimulated() or #userIds == 0 then
		return
	end

	pcall(function()
		self:GetRegistry():UpdateAsync(key, function(raw: any): any
			const entry = sanitizeEntry(raw)
			if not entry then
				return nil
			end

			for _, userId in userIds do
				entry.Pending[tostring(userId)] = nil
			end
			entry.Reserved = countPending(entry.Pending, os.time())
			return entry
		end, MatchmakingSettings.RegistryTTL)
	end)
end

function MatchRegistryService:AppendSquad(key: string, userIds: { number })
	self:UpdateConfig(key, function(raw: any): any
		if typeof(raw) ~= "table" or raw.Kind ~= "Match" then
			return nil
		end

		const squads = if typeof(raw.Squads) == "table" then raw.Squads else {}
		table.insert(squads, userIds)
		raw.Squads = squads
		return raw
	end, MatchmakingSettings.MatchConfigTTL)
end

function MatchRegistryService:FindMatch(modes: { string }, userIds: { number }): Target?
	const now = os.time()
	const candidates: { { Key: string, Entry: Entry, Fill: number } } = {}

	for key, entry in self:ListMatches() do
		if table.find(modes, entry.Mode) and self:HasRoom(entry, #userIds, now) then
			table.insert(candidates, {
				Key = key,
				Entry = entry,
				Fill = entry.Players + countPending(entry.Pending, now),
			})
		end
	end

	table.sort(candidates, function(a: { Fill: number }, b: { Fill: number }): boolean
		return a.Fill > b.Fill
	end)

	for index = 1, math.min(#candidates, MatchmakingSettings.JoinCandidates) do
		const candidate = candidates[index]
		if self:ReserveSlots(candidate.Key, userIds) then
			self:AppendSquad(candidate.Key, userIds)
			return { Key = candidate.Key, AccessCode = candidate.Entry.AccessCode }
		end
	end

	return nil
end

function MatchRegistryService:RegisterMatch(key: string, config: { [string]: any }, userIds: { number }): boolean
	const now = os.time()
	const pending: { [string]: number } = {}
	for _, userId in userIds do
		pending[tostring(userId)] = now + MatchmakingSettings.ReservationTTL
	end

	const mode = GameModes.Modes[config.Mode]
	const entry: Entry = {
		AccessCode = config.AccessCode,
		Map = config.Map,
		Mode = config.Mode,
		Players = 0,
		Reserved = #userIds,
		MaxPlayers = GameModes.GetMaxPlayers(config.Mode),
		JoinInProgress = mode ~= nil and mode.AllowJoinInProgress,
		Private = config.Private == true,
		UpdatedAt = now,
		Pending = pending,
	}

	if self:IsSimulated() then
		return true
	end

	const ok, reason = self:Attempt(function()
		return self:GetRegistry():SetAsync(key, entry, MatchmakingSettings.RegistryTTL)
	end)
	if not ok then
		self:WarnOnce("RegisterMatch", reason)
	end
	return ok
end

function MatchRegistryService:IsPublicMatch(): boolean
	const roleService = self.Dependencies.ServerRoleService
	const config = roleService:GetConfig()
	return roleService:IsMatch() and self.Key ~= "" and config ~= nil and not config.Private
end

function MatchRegistryService:JoinInProgress(): boolean
	const config = self.Dependencies.ServerRoleService:GetConfig()
	if not config then
		return false
	end

	const mode = GameModes.Modes[config.Mode]
	if not mode then
		return false
	end

	return mode.AllowJoinInProgress or self.Dependencies.RoundService.Status() == "Starting"
end

function MatchRegistryService:BeatMatch()
	const roleService = self.Dependencies.ServerRoleService
	const config = roleService:GetConfig()
	const raw = roleService:GetRaw()
	if not config or not raw or typeof(raw.AccessCode) ~= "string" then
		return
	end

	const count = #Players:GetPlayers()
	const joinInProgress = self:JoinInProgress()
	const ok, reason = pcall(function()
		self:GetRegistry():UpdateAsync(self.Key, function(previous: any): any
			const now = os.time()
			const old = sanitizeEntry(previous)
			const pending: { [string]: number } = if old then old.Pending else {}
			for userId, expires in pending do
				const id = tonumber(userId)
				if expires <= now or (id ~= nil and Players:GetPlayerByUserId(id) ~= nil) then
					pending[userId] = nil
				end
			end

			const entry: Entry = {
				AccessCode = raw.AccessCode,
				Map = config.Map,
				Mode = config.Mode,
				Players = count,
				Reserved = countPending(pending, now),
				MaxPlayers = GameModes.GetMaxPlayers(config.Mode),
				JoinInProgress = joinInProgress,
				Private = false,
				UpdatedAt = now,
				Pending = pending,
			}
			return entry
		end, MatchmakingSettings.RegistryTTL)
	end)
	if not ok then
		self:WarnOnce("Heartbeat", reason)
	end
end

function MatchRegistryService:RefreshConfigs()
	const roleService = self.Dependencies.ServerRoleService
	const raw = roleService:GetRaw()
	if not raw or self.Key == "" or not roleService:IsMatch() then
		return
	end

	local latest: any = nil
	const ok = self:UpdateConfig(self.Key, function(current: any): any
		latest = if typeof(current) == "table" and current.Kind == "Match" then current else raw
		return latest
	end, MatchmakingSettings.MatchConfigTTL)

	if ok and typeof(latest) == "table" and typeof(latest.Squads) == "table" then
		raw.Squads = latest.Squads
	end
end

function MatchRegistryService:BeatLobby()
	const raw = self.Dependencies.ServerRoleService:GetRaw()
	const count = #Players:GetPlayers()
	if not raw or raw.Kind ~= "Lobby" or self.Key == "" or count == 0 then
		return
	end

	const lobby = table.clone(raw)
	lobby.Players = count
	const ok, reason = self:SetConfig(self.Key, lobby, MatchmakingSettings.LobbyConfigTTL)
	if not ok then
		self:WarnOnce("LobbyHeartbeat", reason)
	end
end

function MatchRegistryService:Heartbeat()
	const roleService = self.Dependencies.ServerRoleService
	if roleService:IsLobby() then
		self:BeatLobby()
		return
	end

	if not roleService:IsMatch() then
		return
	end

	if self:IsPublicMatch() then
		self:BeatMatch()
	end

	const now = os.clock()
	if now - self.LastConfigRefresh >= MatchmakingSettings.ConfigRefreshInterval then
		self.LastConfigRefresh = now
		self:RefreshConfigs()
	end
end

function MatchRegistryService:RequestHeartbeat()
	if not self.Running then
		return
	end

	if self.Beating then
		self.Queued = true
		return
	end

	self.Beating = true
	task.spawn(function()
		repeat
			self.Queued = false
			self:Heartbeat()
		until not self.Queued
		self.Beating = false
	end)
end

function MatchRegistryService:Cleanup()
	if self.Key == "" or self:IsSimulated() then
		return
	end

	const raw = self.Dependencies.ServerRoleService:GetRaw()
	if raw and raw.Kind == "Lobby" then
		const lobby = table.clone(raw)
		lobby.Players = 0
		pcall(function()
			self:GetConfigMap():SetAsync(self.Key, lobby, MatchmakingSettings.LobbyConfigTTL)
		end)
		return
	end

	if not self:IsPublicMatch() then
		return
	end

	pcall(function()
		self:GetRegistry():RemoveAsync(self.Key)
	end)
end

function MatchRegistryService:Begin()
	const roleService = self.Dependencies.ServerRoleService
	if self.Key == "" or roleService:IsRouter() or roleService:GetRaw() == nil then
		return
	end

	if roleService:IsLobby() then
		workspace:SetAttribute("LobbyId", self.Key)
	end

	self.Running = true
	self.LastConfigRefresh = os.clock()

	task.spawn(function()
		while self.Running do
			self:RequestHeartbeat()
			task.wait(MatchmakingSettings.HeartbeatInterval)
		end
	end)

	self.Dependencies.PlayerService.PlayerAdded:Connect(function()
		self:RequestHeartbeat()
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function()
		task.defer(function()
			self:RequestHeartbeat()
		end)
	end)

	if roleService:IsMatch() then
		self.Libs.Charm.subscribe(self.Dependencies.RoundService.Status, function()
			self:RequestHeartbeat()
		end)
	end
end

MatchRegistryService:OnInit(function(self)
	self:Setup()
end)

MatchRegistryService:OnStart(function(self)
	self.Dependencies.ServerRoleService:OnReady(function()
		self:Begin()
	end)

	game:BindToClose(function()
		self.Running = false
		self:Cleanup()
	end)
end)

return MatchRegistryService
