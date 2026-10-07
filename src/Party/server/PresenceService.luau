--!strict
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local PartySettings = require(ReplicatedStorage.shared.Party.PartySettings)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

export type Role = "Lobby" | "Match"
export type Presence = { Job: string, Role: Role, Squad: string, At: number }
export type Message = { [string]: any }

const PresenceService = Modux.Service("PresenceService", {
	Require = { "PlayerService", "ServerRoleService" },
	Priority = 840,
})

function PresenceService:Setup()
	self.JobId = (if game.JobId == "" then "studio" else game.JobId) :: string
	self.Map = nil :: MemoryStoreHashMap?
	self.Active = false :: boolean
	self.Remote = (not RunService:IsStudio()) :: boolean
	self.Role = "Lobby" :: Role
	self.Squads = {} :: { [Player]: string }
	self.Warned = {} :: { [string]: boolean }
	self.Subscribed = false :: boolean
	self.Message = self.Libs.Signal.new() :: SignalLib.Signal<Message>
end

function PresenceService:WarnOnce(label: string, reason: any)
	if self.Warned[label] then
		return
	end

	self.Warned[label] = true
	warn(`[PresenceService] {label}: {tostring(reason)}`)
end

function PresenceService:GetMap(): MemoryStoreHashMap
	if not self.Map then
		self.Map = MemoryStoreService:GetHashMap(PartySettings.PresenceMapName)
	end

	return self.Map :: MemoryStoreHashMap
end

function PresenceService:IsActive(): boolean
	return self.Active
end

function PresenceService:Topic(jobId: string): string
	return PartySettings.TopicPrefix .. jobId
end

function PresenceService:GetSquad(player: Player): string?
	return self.Squads[player]
end

function PresenceService:SetSquad(player: Player, key: string?)
	if self.Squads[player] == key then
		return
	end

	self.Squads[player] = key
	if self.Active then
		task.spawn(function()
			self:Write(player)
		end)
	end
end

function PresenceService:Write(player: Player)
	if not self.Active or not self.Remote or not self.Subscribed or not player:IsDescendantOf(Players) then
		return
	end

	const entry: Presence = {
		Job = self.JobId,
		Role = self.Role,
		Squad = self.Squads[player] or "",
		At = os.time(),
	}
	const ok, reason = pcall(function()
		self:GetMap():UpdateAsync(tostring(player.UserId), function(): any
			if not player:IsDescendantOf(Players) then
				return nil
			end
			return entry
		end, PartySettings.PresenceTTL)
	end)
	if not ok then
		self:WarnOnce("Write", reason)
	end
end

function PresenceService:Clear(userId: number)
	if not self.Remote then
		return
	end

	const jobId = self.JobId
	pcall(function()
		self:GetMap():UpdateAsync(tostring(userId), function(raw: any): any
			if typeof(raw) ~= "table" or raw.Job ~= jobId then
				return nil
			end
			raw.Gone = true
			return raw
		end, PartySettings.PresenceGoneTTL)
	end)
end

function PresenceService:Read(userId: number): (Presence?, boolean)
	const player = Players:GetPlayerByUserId(userId)
	if player and self.Active then
		return { Job = self.JobId, Role = self.Role, Squad = self.Squads[player] or "", At = os.time() }, true
	end

	if not self.Remote then
		return nil, true
	end

	const ok, raw = pcall(function(): any
		return self:GetMap():GetAsync(tostring(userId))
	end)
	if not ok then
		self:WarnOnce("Read", raw)
		return nil, false
	end

	if typeof(raw) ~= "table" or raw.Gone == true or typeof(raw.Job) ~= "string" then
		return nil, true
	end

	const role: Role = if raw.Role == "Match" then "Match" else "Lobby"
	return {
		Job = raw.Job,
		Role = role,
		Squad = if typeof(raw.Squad) == "string" then raw.Squad else "",
		At = if typeof(raw.At) == "number" then raw.At else 0,
	}, true
end

function PresenceService:Send(jobId: string, message: Message): (boolean, string?)
	if jobId == self.JobId then
		task.spawn(function()
			self.Message:Fire(message)
		end)
		return true, nil
	end

	if not self.Remote then
		return false, "unavailable"
	end

	const ok, reason = pcall(function()
		MessagingService:PublishAsync(self:Topic(jobId), message)
	end)
	if not ok then
		self:WarnOnce("Send", reason)
		return false, tostring(reason)
	end
	return true, nil
end

function PresenceService:SendToUser(userId: number, message: Message): (boolean, string?)
	const presence = self:Read(userId)
	if not presence then
		return false, "offline"
	end
	return self:Send(presence.Job, message)
end

function PresenceService:Subscribe()
	if self.Subscribed or not self.Remote then
		return
	end

	const onPacket = function(packet: any)
		const data = if typeof(packet) == "table" then packet.Data else nil
		if typeof(data) == "table" and typeof(data.K) == "string" then
			self.Message:Fire(data)
		end
	end

	local delay = PartySettings.SubscribeBackoff
	while self.Active do
		const ok, reason = pcall(function()
			MessagingService:SubscribeAsync(self:Topic(self.JobId), onPacket)
		end)
		if ok then
			break
		end

		self:WarnOnce("Subscribe", reason)
		task.wait(delay)
		delay = math.min(delay * 2, PartySettings.SubscribeBackoffMax)
	end

	if self.Active then
		self.Subscribed = true
		self:BeatAll()
	end
end

function PresenceService:BeatAll()
	for _, player in Players:GetPlayers() do
		self:Write(player)
	end
end

function PresenceService:Activate(role: Role)
	self.Role = role
	self.Active = true

	task.spawn(function()
		self:Subscribe()
	end)

	task.spawn(function()
		while self.Active do
			self:BeatAll()
			task.wait(PartySettings.PresenceInterval)
		end
	end)

	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
		task.spawn(function()
			self:Write(player)
		end)
	end)
end

PresenceService:OnInit(function(self)
	self:Setup()

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.Squads[player] = nil
		if self.Active then
			const userId = player.UserId
			task.spawn(function()
				self:Clear(userId)
			end)
		end
	end)
end)

PresenceService:OnStart(function(self)
	const roleService = self.Dependencies.ServerRoleService
	roleService:OnReady(function()
		if roleService:IsLobby() then
			self:Activate("Lobby")
		elseif roleService:IsMatch() then
			self:Activate("Match")
		end
	end)

	game:BindToClose(function()
		if not self.Active then
			return
		end

		self.Active = false
		for _, player in Players:GetPlayers() do
			self:Clear(player.UserId)
		end
	end)
end)

return PresenceService
