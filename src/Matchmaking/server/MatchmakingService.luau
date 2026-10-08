--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GameModes = require(ReplicatedStorage.shared.Match.GameModes)
local Maps = require(ReplicatedStorage.shared.Match.Maps)
local MatchmakingNet = require(ReplicatedStorage.shared.Matchmaking.Net)
local MatchmakingSettings = require(ReplicatedStorage.shared.Matchmaking.MatchmakingSettings)
local Modux = require(ServerScriptService.server.Modux)

type PlayMode = MatchmakingNet.PlayMode
type State = MatchmakingNet.State
type Target = { Key: string, AccessCode: string }
type Finder = (userIds: { number }) -> (Target?, string?)
type Search = {
	Token: number,
	Squad: string,
	Leader: Player,
	UserIds: { number },
	Target: Target?,
	Started: number,
}

const PLAY_MODES: { [string]: boolean } = { QuickPlay = true, FFA = true, TDM = true, Practice = true }

local function presentPlayers(userIds: { number }): { Player }
	const present: { Player } = {}
	for _, userId in userIds do
		const player = Players:GetPlayerByUserId(userId)
		if player then
			table.insert(present, player)
		end
	end
	return present
end

local function modesFor(mode: PlayMode): { string }
	if mode ~= "QuickPlay" then
		return { mode }
	end

	const modes: { string } = {}
	for _, name in MatchmakingSettings.QuickPlayModes do
		const definition = GameModes.Modes[name]
		if definition and not definition.Ranked and definition.AllowJoinInProgress then
			table.insert(modes, name)
		end
	end
	return modes
end

local function mapAllows(mapName: string, modeName: string): boolean
	const map = Maps[mapName]
	return map ~= nil and table.find(map.Modes, modeName) ~= nil
end

local function pickMap(modeName: string): string?
	const options: { string } = {}
	for mapName, map in Maps do
		if table.find(map.Modes, modeName) then
			table.insert(options, mapName)
		end
	end

	if #options == 0 then
		return nil
	end

	return options[math.random(1, #options)]
end

local function userIdsOf(players: { Player }): { number }
	const userIds: { number } = {}
	for _, player in players do
		table.insert(userIds, player.UserId)
	end
	return userIds
end

const MatchmakingService = Modux.Service("MatchmakingService", {
	Require = {
		"NetService",
		"PlayerService",
		"ServerRoleService",
		"GameStateService",
		"RoundService",
		"MatchRegistryService",
		"TeleportGateway",
		"SquadService",
	},
	Priority = 550,
})

function MatchmakingService:Setup()
	self.Order = {} :: { Player }
	self.States = {} :: { [Player]: State }
	self.Returning = {} :: { [Player]: boolean }
	self.Search = nil :: Search?
	self.Token = 0 :: number
	self.LastPlay = 0 :: number
	self.LobbyActive = false :: boolean
	self.MatchActive = false :: boolean
	self.RoomCache = {} :: { MatchmakingNet.Room }
	self.RoomCacheAt = 0 :: number
	self.RoomListAt = {} :: { [Player]: number }
end

function MatchmakingService:SetStatus(players: { Player }, state: State, reason: string?)
	const netService = self.Dependencies.NetService
	for _, player in players do
		self.States[player] = state
		if netService:IsRunning() and netService:IsReady(player) then
			self.Libs.Net.Matchmaking.Status:fireClient(player, {
				State = state,
				Reason = string.sub(reason or "", 1, 200),
			})
		end
	end
end

function MatchmakingService:GetLeader(): Player?
	const squad = self.Dependencies.SquadService
	if squad:GetRecord() ~= nil then
		return squad:GetLeader()
	end

	const owner = self.Dependencies.MatchRegistryService:GetOwner()
	if owner then
		const ownerPlayer = Players:GetPlayerByUserId(owner)
		if ownerPlayer then
			return ownerPlayer
		end
	end

	for _, player in self.Order do
		if player:IsDescendantOf(Players) then
			return player
		end
	end

	return nil
end

function MatchmakingService:PublishLeader()
	if not self.LobbyActive then
		return
	end

	const leader = self:GetLeader()
	workspace:SetAttribute("LobbyLeader", if leader then leader.UserId else nil)
end

function MatchmakingService:IsBusy(): boolean
	const search = self.Search
	if not search then
		return false
	end

	if os.clock() - search.Started > MatchmakingSettings.SearchTimeout and search.Target ~= nil then
		self:EndSearch(search.Token)
		return false
	end

	return true
end

function MatchmakingService:EndSearch(token: number?, keepTraveling: boolean?)
	const search = self.Search
	if not search or (token ~= nil and search.Token ~= token) then
		return
	end

	self.Search = nil
	if not keepTraveling then
		self.Dependencies.SquadService:MarkTraveling(presentPlayers(search.UserIds), false)
	end
end

function MatchmakingService:Validate(player: Player): string?
	if not self.LobbyActive then
		return "Matchmaking indisponivel neste servidor"
	end

	if not self.Dependencies.GameStateService:Is("Lobby") then
		return "O lobby ainda nao esta pronto"
	end

	if self:GetLeader() ~= player then
		return "Apenas o lider do squad pode iniciar a partida"
	end

	if self:IsBusy() then
		return "Ja existe uma busca em andamento"
	end

	if self.Dependencies.SquadService:AnyTraveling() then
		return "Aguarde o squad terminar de viajar"
	end

	const blocker = self.Dependencies.SquadService:PlayBlocker()
	if blocker then
		return blocker
	end

	if os.clock() - self.LastPlay < MatchmakingSettings.PlayCooldown then
		return "Aguarde alguns segundos antes de tentar novamente"
	end

	return nil
end

function MatchmakingService:Create(
	modeName: string,
	private: boolean,
	userIds: { number },
	chosenMap: string?,
	withCode: boolean?
): (Target?, string?)
	const mode = GameModes.Modes[modeName]
	const mapName = if chosenMap and mapAllows(chosenMap, modeName) then chosenMap else pickMap(modeName)
	if not mode or not mapName then
		return nil, `Nenhum mapa disponivel para {modeName}`
	end

	const registry = self.Dependencies.MatchRegistryService
	const reservation, reason = self.Dependencies.TeleportGateway:Reserve()
	if not reservation then
		return nil, reason
	end

	local code: string? = nil
	if withCode then
		code = registry:ClaimCode({
			Key = reservation.ServerId,
			AccessCode = reservation.AccessCode,
			Private = private,
		})
		if not code then
			return nil, "Falha ao gerar codigo da sala"
		end
	end

	const config = {
		Kind = "Match",
		Map = mapName,
		Mode = modeName,
		Ranked = mode.Ranked,
		Private = private,
		AccessCode = reservation.AccessCode,
		Squads = { userIds },
		Created = os.time(),
		Code = code,
	}

	const saved, saveReason = registry:SetConfig(reservation.ServerId, config, MatchmakingSettings.MatchConfigTTL)
	if not saved then
		return nil, `Falha ao registrar partida: {saveReason}`
	end

	if not private then
		registry:RegisterMatch(reservation.ServerId, config, userIds)
	end

	return { Key = reservation.ServerId, AccessCode = reservation.AccessCode }, nil
end

function MatchmakingService:FindTarget(mode: PlayMode, userIds: { number }): (Target?, string?)
	if mode == "Practice" then
		return self:Create(MatchmakingSettings.PracticeMode, true, userIds)
	end

	const existing = self.Dependencies.MatchRegistryService:FindMatch(modesFor(mode), userIds)
	if existing then
		return existing, nil
	end

	const modeName = if mode == "QuickPlay" then MatchmakingSettings.DefaultQuickPlayMode else mode
	return self:Create(modeName, false, userIds)
end

function MatchmakingService:Travelers(): { Player }
	const members = self.Dependencies.SquadService:PresentMembers()
	return if #members > 0 then members else Players:GetPlayers()
end

function MatchmakingService:FindRoom(code: string, userIds: { number }): (Target?, string?)
	const registry = self.Dependencies.MatchRegistryService
	const room = registry:FindCode(code)
	if not room then
		return nil, "Sala nao encontrada"
	end

	if not room.Private and not registry:IsSimulated() and not registry:ReserveSlots(room.Key, userIds) then
		return nil, "Sala lotada ou encerrada"
	end

	registry:AppendSquad(room.Key, userIds)
	return { Key = room.Key, AccessCode = room.AccessCode }, nil
end

function MatchmakingService:Run(search: Search, find: Finder)
	const token = search.Token
	const userIds = search.UserIds
	self:SetStatus(presentPlayers(userIds), "Searching", "")

	const found, target, reason = pcall(find, userIds)

	if token ~= self.Token then
		if found and target then
			self.Dependencies.MatchRegistryService:ReleaseSlots(target.Key, userIds)
		end
		return
	end

	if not found or not target then
		self:SetStatus(Players:GetPlayers(), "Failed", if found then reason else tostring(target))
		self:EndSearch(token)
		return
	end

	search.Target = target
	const travelers = presentPlayers(userIds)
	self:SetStatus(travelers, "Teleporting", "")
	self.Dependencies.SquadService:MarkTraveling(travelers, true)

	const teleported, teleportReason = self.Dependencies.TeleportGateway:Teleport(
		travelers,
		target.AccessCode,
		{ ReturnLobby = self.Dependencies.MatchRegistryService:GetLobbyKey() }
	)

	if not teleported then
		self.Dependencies.MatchRegistryService:ReleaseSlots(target.Key, userIds)
		self:SetStatus(Players:GetPlayers(), "Failed", teleportReason)
		self:EndSearch(token)
	elseif self.Dependencies.TeleportGateway:IsSimulated() then
		task.wait(MatchmakingSettings.StudioTeleportDelay)
		if token == self.Token then
			self:SetStatus(Players:GetPlayers(), "Idle", "")
		end
		self:EndSearch(token)
	end
end

function MatchmakingService:Play(player: Player, mode: string): (boolean, string)
	if not PLAY_MODES[mode] then
		return false, "Modo invalido"
	end

	return self:Begin(player, function(userIds: { number }): (Target?, string?)
		return self:FindTarget(mode :: PlayMode, userIds)
	end)
end

function MatchmakingService:CreateRoom(player: Player, mode: string, mapName: string, private: boolean): (boolean, string)
	if not table.find(MatchmakingSettings.RoomModes, mode) then
		return false, "Modo invalido"
	end

	if mapName ~= "" and not mapAllows(mapName, mode) then
		return false, "Mapa invalido para este modo"
	end

	return self:Begin(player, function(userIds: { number }): (Target?, string?)
		return self:Create(mode, private, userIds, if mapName ~= "" then mapName else nil, true)
	end)
end

function MatchmakingService:JoinRoom(player: Player, code: string): (boolean, string)
	if code == "" then
		return false, "Digite o codigo da sala"
	end

	return self:Begin(player, function(userIds: { number }): (Target?, string?)
		return self:FindRoom(code, userIds)
	end)
end

function MatchmakingService:JoinMatch(player: Player, key: string): (boolean, string)
	if key == "" then
		return false, "Sala invalida"
	end

	return self:Begin(player, function(userIds: { number }): (Target?, string?)
		const target = self.Dependencies.MatchRegistryService:JoinKey(key, userIds)
		return target, if target then nil else "Sala lotada ou encerrada"
	end)
end

function MatchmakingService:ListRooms(player: Player): { MatchmakingNet.Room }
	if not self.LobbyActive then
		return {}
	end

	const now = os.clock()
	const last = self.RoomListAt[player]
	if last and now - last < MatchmakingSettings.RoomListCooldown then
		return self.RoomCache
	end
	self.RoomListAt[player] = now

	if self.RoomCacheAt == 0 or now - self.RoomCacheAt >= MatchmakingSettings.RoomListCooldown then
		self.RoomCacheAt = now
		self.RoomCache = self.Dependencies.MatchRegistryService:ListRooms(MatchmakingSettings.RoomListLimit)
	end

	return self.RoomCache
end

function MatchmakingService:Begin(player: Player, find: Finder): (boolean, string)
	const problem = self:Validate(player)
	if problem then
		return false, problem
	end

	self.LastPlay = os.clock()
	self.Token += 1
	const search: Search = {
		Token = self.Token,
		Squad = self.Dependencies.SquadService:GetKey(),
		Leader = player,
		UserIds = userIdsOf(self:Travelers()),
		Target = nil,
		Started = os.clock(),
	}
	self.Search = search

	task.spawn(function()
		self:Run(search, find)
	end)

	return true, ""
end

function MatchmakingService:OnTeleportFailed(player: Player, reason: string)
	const search = self.Search
	if not search or not table.find(search.UserIds, player.UserId) then
		return
	end

	self.Dependencies.SquadService:MarkTraveling({ player }, false)
	if search.Target then
		self.Dependencies.MatchRegistryService:ReleaseSlots(search.Target.Key, { player.UserId })
	end
	self:SetStatus({ player }, "Failed", reason)

	if player == search.Leader then
		self:EndSearch(search.Token)
	end
end

function MatchmakingService:Cancel(player: Player)
	const search = self.Search
	if not self.LobbyActive or not search or search.Leader ~= player or search.Target ~= nil then
		return
	end

	if self.States[player] ~= "Searching" then
		return
	end

	self.Token += 1
	self:EndSearch(search.Token)
	self:SetStatus(Players:GetPlayers(), "Idle", "")
end

function MatchmakingService:ReturnToLobby(player: Player, reason: string?)
	if not self.MatchActive or self.Returning[player] or not player:IsDescendantOf(Players) then
		return
	end
	self.Returning[player] = true
	self:SetStatus({ player }, "Teleporting", reason)

	const registry = self.Dependencies.MatchRegistryService
	const returnKey = self.Dependencies.SquadService:GetReturnKey(player)

	local target: Target? = nil
	local failure: string? = nil
	if returnKey then
		const lobby = registry:FindLobby(returnKey)
		if lobby then
			target = { Key = lobby.Key, AccessCode = lobby.AccessCode }
		end
	end

	if not target then
		target, failure = registry:CreateLobby(player.UserId)
	end

	local teleported = false
	if target then
		teleported, failure = self.Dependencies.TeleportGateway:Teleport(
			{ player },
			target.AccessCode,
			{ ReturnLobby = target.Key }
		)
	end

	if not teleported then
		self.Returning[player] = nil
		self:SetStatus({ player }, "Failed", failure or "Falha ao voltar ao lobby")
		return
	end

	if self.Dependencies.TeleportGateway:IsSimulated() then
		task.wait(MatchmakingSettings.StudioTeleportDelay)
		self.Returning[player] = nil
		self:SetStatus({ player }, "Idle", "")
	end
end

function MatchmakingService:ReturnAll(reason: string?)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:ReturnToLobby(player, reason)
		end)
	end
end

function MatchmakingService:InSquads(player: Player): boolean
	const raw = self.Dependencies.ServerRoleService:GetRaw()
	const squads = if raw then raw.Squads else nil
	if typeof(squads) ~= "table" then
		return false
	end

	for _, squad in squads do
		if typeof(squad) == "table" and table.find(squad, player.UserId) then
			return true
		end
	end
	return false
end

function MatchmakingService:AdmissionProblem(player: Player): string?
	const config = self.Dependencies.ServerRoleService:GetConfig()
	if not config then
		return nil
	end

	const mode = GameModes.Modes[config.Mode]
	const member = config.Private and self:InSquads(player)
	if config.Private and not member then
		return "Esta partida e privada"
	end

	if #Players:GetPlayers() > GameModes.GetMaxPlayers(config.Mode) then
		return "A partida esta lotada"
	end

	if mode and not mode.AllowJoinInProgress and not member and self.Dependencies.RoundService.Status() ~= "Starting" then
		return "A partida ja comecou"
	end

	return nil
end

function MatchmakingService:Admit(player: Player)
	const problem = self:AdmissionProblem(player)
	if not problem then
		return
	end

	task.wait(MatchmakingSettings.AdmissionDelay)
	self:ReturnToLobby(player, problem)
end

function MatchmakingService:ActivateLobby()
	self.LobbyActive = true
	self:PublishLeader()
end

function MatchmakingService:ActivateMatch()
	self.MatchActive = true

	const raw = self.Dependencies.ServerRoleService:GetRaw()
	if raw and typeof(raw.Code) == "string" then
		workspace:SetAttribute("RoomCode", raw.Code)
	end

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:Admit(player)
		end)
	end

	self.Libs.Charm.subscribe(self.Dependencies.RoundService.Status, function(status, previous)
		const config = self.Dependencies.ServerRoleService:GetConfig()
		if config and config.Ranked and status == "Intermission" and previous == "Match" then
			task.delay(MatchmakingSettings.RankedReturnDelay, function()
				self:ReturnAll(nil)
			end)
		end
	end)
end

function MatchmakingService:OnPlayerAdded(player: Player)
	table.insert(self.Order, player)

	if self.LobbyActive then
		self:PublishLeader()
	elseif self.MatchActive then
		task.spawn(function()
			self:Admit(player)
		end)
	end
end

function MatchmakingService:OnPlayerRemoving(player: Player)
	const index = table.find(self.Order, player)
	if index then
		table.remove(self.Order, index)
	end

	self.States[player] = nil
	self.Returning[player] = nil
	self.RoomListAt[player] = nil

	const search = self.Search
	if search and search.Leader == player then
		self:EndSearch(search.Token, search.Target ~= nil)
	end

	self:PublishLeader()
end

function MatchmakingService:BindNet()

	const net = self.Libs.Net.Matchmaking

	net.Play:onServer(function(request, player)
		const accepted, reason = self:Play(player, request.Mode)
		return { Accepted = accepted, Reason = reason }
	end)

	net.CreateRoom:onServer(function(request, player)
		const accepted, reason = self:CreateRoom(player, request.Mode, request.Map, request.Private)
		return { Accepted = accepted, Reason = reason }
	end)

	net.JoinRoom:onServer(function(request, player)
		const accepted, reason = self:JoinRoom(player, request.Code)
		return { Accepted = accepted, Reason = reason }
	end)

	net.JoinMatch:onServer(function(request, player)
		const accepted, reason = self:JoinMatch(player, request.Key)
		return { Accepted = accepted, Reason = reason }
	end)

	net.ListRooms:onServer(function(_, player)
		return { Rooms = self:ListRooms(player) }
	end)

	net.Cancel:onServer(function(_, player)
		self:Cancel(player)
	end)

	net.ReturnToLobby:onServer(function(_, player)
		task.spawn(function()
			self:ReturnToLobby(player, nil)
		end)
	end)

	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
		self:OnPlayerAdded(player)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:OnPlayerRemoving(player)
	end)
end

function MatchmakingService:Start()
	const roleService = self.Dependencies.ServerRoleService
	roleService:OnReady(function()
		if roleService:IsLobby() then
			self:ActivateLobby()
		elseif roleService:IsMatch() then
			self:ActivateMatch()
		end
	end)

	self.Dependencies.SquadService.Changed:Connect(function()
		self:PublishLeader()
	end)

	self.Dependencies.TeleportGateway.Failed:Connect(function(player, reason)
		if self.LobbyActive then
			self:OnTeleportFailed(player, reason)
		elseif self.MatchActive then
			self.Returning[player] = nil
			self:SetStatus({ player }, "Failed", reason)
		end
	end)

	self.Dependencies.NetService.ClientReady:Connect(function(player)
		const state = self.States[player]
		if state then
			self:SetStatus({ player }, state, "")
		end
	end)
end

MatchmakingService:OnInit(function(self)
	self:Setup()
	self:BindNet()
end)

MatchmakingService:OnStart(function(self)
	self:Start()
end)

return MatchmakingService
