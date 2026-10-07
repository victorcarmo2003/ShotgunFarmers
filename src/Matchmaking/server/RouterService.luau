--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MatchmakingSettings = require(ReplicatedStorage.shared.Matchmaking.MatchmakingSettings)
local PartySettings = require(ReplicatedStorage.shared.Party.PartySettings)
local SquadRecord = require(ReplicatedStorage.shared.Party.SquadRecord)
local Modux = require(ServerScriptService.server.Modux)

const KICK_MESSAGE = "Nao foi possivel encontrar um lobby. Tente entrar novamente."

const RouterService = Modux.Service("RouterService", {
	Require = { "PlayerService", "ServerRoleService", "MatchRegistryService", "TeleportGateway", "SquadStore" },
	Priority = 860,
})

function RouterService:Setup()
	self.Active = false :: boolean
	self.Routing = {} :: { [Player]: boolean }
	self.Attempts = {} :: { [Player]: number }
end

function RouterService:ReadJoinKeys(player: Player): { string }
	const keys: { string } = {}
	const ok, joinData = pcall(function(): any
		return player:GetJoinData()
	end)
	if not ok or typeof(joinData) ~= "table" then
		return keys
	end

	const teleportData = joinData.TeleportData
	if typeof(teleportData) == "table" and typeof(teleportData.ReturnLobby) == "string" then
		table.insert(keys, teleportData.ReturnLobby)
	end

	const launchData = joinData.LaunchData
	if typeof(launchData) == "string" and launchData ~= "" then
		const decoded, data = pcall(function()
			return HttpService:JSONDecode(launchData)
		end)
		if decoded and typeof(data) == "table" and typeof(data.Lobby) == "string" then
			table.insert(keys, data.Lobby)
		end
	end

	return keys
end

function RouterService:CanEnter(player: Player, key: string, owner: number?): boolean
	const ok, record = self.Dependencies.SquadStore:Get(key)
	if not ok then
		return false
	end

	const userId = player.UserId
	if record and SquadRecord.find(record, userId) then
		return true
	end

	const size = if record then #record.Members else 0
	const capacity = math.min(MatchmakingSettings.LobbyCapacity, PartySettings.MaxSize)
	if size >= capacity then
		return false
	end

	return owner == userId or self.Dependencies.SquadStore:HasToken(key, userId)
end

function RouterService:ResolveExisting(player: Player): (string?, string?)
	const registry = self.Dependencies.MatchRegistryService
	for _, key in self:ReadJoinKeys(player) do
		const lobby = registry:FindLobby(key)
		if lobby and self:CanEnter(player, lobby.Key, lobby.Owner) then
			return lobby.Key, lobby.AccessCode
		end
	end
	return nil, nil
end

function RouterService:TryRoute(player: Player): (boolean, string?)
	local key, accessCode = self:ResolveExisting(player)
	if not accessCode then
		const target, reason = self.Dependencies.MatchRegistryService:CreateLobby(player.UserId)
		if not target then
			return false, reason
		end
		key, accessCode = target.Key, target.AccessCode
	end

	if not player:IsDescendantOf(Players) then
		return true, nil
	end

	return self.Dependencies.TeleportGateway:Teleport({ player }, accessCode, { ReturnLobby = key })
end

function RouterService:Route(player: Player)
	if self.Routing[player] or not player:IsDescendantOf(Players) then
		return
	end
	self.Routing[player] = true

	while player:IsDescendantOf(Players) do
		const attempts = (self.Attempts[player] or 0) + 1
		self.Attempts[player] = attempts

		const routed, reason = self:TryRoute(player)
		if routed then
			break
		end

		warn(`[RouterService] falha ao rotear {player.Name} (tentativa {attempts}): {tostring(reason)}`)
		if attempts >= MatchmakingSettings.RouterAttempts then
			player:Kick(KICK_MESSAGE)
			break
		end

		task.wait(MatchmakingSettings.RouterRetryDelay)
	end

	self.Routing[player] = nil
end

function RouterService:RouteAsync(player: Player)
	task.spawn(function()
		self:Route(player)
	end)
end

function RouterService:Activate()
	self.Active = true

	for _, player in Players:GetPlayers() do
		self:RouteAsync(player)
	end
end

RouterService:OnInit(function(self)
	self:Setup()

	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
		if self.Active then
			self:RouteAsync(player)
		end
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.Routing[player] = nil
		self.Attempts[player] = nil
	end)
end)

RouterService:OnStart(function(self)
	const roleService = self.Dependencies.ServerRoleService
	roleService:OnReady(function()
		if roleService:IsRouter() then
			self:Activate()
		end
	end)

	self.Dependencies.TeleportGateway.Failed:Connect(function(player, reason)
		if not self.Active then
			return
		end

		warn(`[RouterService] teleporte de {player.Name} falhou: {reason}`)
		if (self.Attempts[player] or 0) >= MatchmakingSettings.RouterAttempts then
			player:Kick(KICK_MESSAGE)
			return
		end

		task.delay(MatchmakingSettings.RouterRetryDelay, function()
			self:RouteAsync(player)
		end)
	end)
end)

return RouterService
