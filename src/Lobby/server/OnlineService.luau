--!strict
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Lync = require(ReplicatedStorage.Packages.Lync)
local Modux = require(ServerScriptService.server.Modux)

const MAP_NAME = "Online"
const META_NAME = "OnlineMeta"
const LOCK_KEY = "OnlineAggregatorLock"
const TOTAL_KEY = "OnlineTotal"
const HEARTBEAT_INTERVAL = 20
const COUNT_TTL = 45
const AGGREGATE_INTERVAL = 30
const LOCK_TTL = 60
const TOTAL_TTL = 120
const PAGE_SIZE = 200
const MAX_PAGES = 50

const OnlineService = Modux.Service("OnlineService", {
	Require = { "PlayerService", "NetService", "ServerRoleService" },
	Priority = 600,
})

function OnlineService:Setup()
	self.Total = 0 :: number
	self.Remote = (not RunService:IsStudio()) :: boolean
	self.Warned = {} :: { [string]: boolean }
	self.Map = nil :: MemoryStoreSortedMap?
	self.Meta = nil :: MemoryStoreHashMap?
	self.Aggregator = false :: boolean
	self.Key = (if game.JobId == "" then "studio" else game.JobId) :: string
end

function OnlineService:WarnOnce(label: string, reason: any)
	if self.Warned[label] then
		return
	end

	self.Warned[label] = true
	warn(`[OnlineService] {label} falhou, usando contagem local: {tostring(reason)}`)
end

function OnlineService:GetMap(): MemoryStoreSortedMap
	if not self.Map then
		self.Map = MemoryStoreService:GetSortedMap(MAP_NAME)
	end

	return self.Map :: MemoryStoreSortedMap
end

function OnlineService:GetMeta(): MemoryStoreHashMap
	if not self.Meta then
		self.Meta = MemoryStoreService:GetHashMap(META_NAME)
	end

	return self.Meta :: MemoryStoreHashMap
end

function OnlineService:Heartbeat()
	const ok, reason = pcall(function()
		self:GetMap():SetAsync(self.Key, { Count = #Players:GetPlayers() }, COUNT_TTL)
	end)
	if not ok then
		self:WarnOnce("Heartbeat", reason)
	end
end

function OnlineService:Remove()
	pcall(function()
		self:GetMap():RemoveAsync(self.Key)
	end)
end

function OnlineService:Claim(): boolean
	local owned = false
	const ok, reason = pcall(function()
		self:GetMeta():UpdateAsync(LOCK_KEY, function(raw: any): any
			owned = false
			const now = os.time()
			if
				typeof(raw) == "table"
				and raw.Owner ~= self.Key
				and typeof(raw.Expires) == "number"
				and raw.Expires > now
			then
				return nil
			end

			owned = true
			return { Owner = self.Key, Expires = now + LOCK_TTL }
		end, LOCK_TTL)
	end)
	if not ok then
		self:WarnOnce("Lock", reason)
		return false
	end
	return owned
end

function OnlineService:Release()
	if not self.Aggregator then
		return
	end

	self.Aggregator = false
	pcall(function()
		self:GetMeta():UpdateAsync(LOCK_KEY, function(raw: any): any
			if typeof(raw) ~= "table" or raw.Owner ~= self.Key then
				return nil
			end
			return { Owner = self.Key, Expires = 0 }
		end, 1)
	end)
end

function OnlineService:Sum(): number?
	local total = 0
	local lowerBound: string? = nil

	for _ = 1, MAX_PAGES do
		const ok, items = pcall(function()
			return self:GetMap():GetRangeAsync(Enum.SortDirection.Ascending, PAGE_SIZE, lowerBound)
		end)
		if not ok then
			self:WarnOnce("Sum", items)
			return nil
		end

		for _, item in items do
			const value = item.value
			if type(value) == "table" and type(value.Count) == "number" then
				total += value.Count
			end
		end

		if #items < PAGE_SIZE then
			break
		end

		lowerBound = items[#items].key
	end

	return total
end

function OnlineService:Aggregate()
	self.Aggregator = self:Claim()
	if not self.Aggregator then
		return
	end

	const sum = self:Sum()
	if not sum then
		return
	end

	const ok, reason = pcall(function()
		self:GetMeta():SetAsync(TOTAL_KEY, { Total = sum, At = os.time() }, TOTAL_TTL)
	end)
	if not ok then
		self:WarnOnce("Total", reason)
	end
end

function OnlineService:ReadTotal(): number?
	const ok, raw = pcall(function(): any
		return self:GetMeta():GetAsync(TOTAL_KEY)
	end)
	if not ok then
		self:WarnOnce("Read", raw)
		return nil
	end

	if typeof(raw) == "table" and typeof(raw.Total) == "number" then
		return raw.Total
	end
	return nil
end

function OnlineService:Publish(to: Lync.Recipient)
	if not self.Dependencies.NetService:IsRunning() then
		return
	end

	self.Libs.Net.Lobby.Online:fireClient(to, math.clamp(self.Total, 0, 10000000))
end

function OnlineService:SetTotal(total: number)
	if total == self.Total then
		return
	end

	self.Total = total
	self:Publish(self.Dependencies.NetService.Audience)
end

function OnlineService:Refresh()
	const localCount = #Players:GetPlayers()
	if not self.Remote then
		self:SetTotal(localCount)
		return
	end

	self:Aggregate()
	const read = self:ReadTotal()
	self:SetTotal(if read then math.max(read, localCount) else localCount)
end

function OnlineService:StartLobby()
	if not self.Remote then
		const update = function()
			task.defer(function()
				self:SetTotal(#Players:GetPlayers())
			end)
		end
		self.Dependencies.PlayerService.PlayerAdded:Connect(update)
		self.Dependencies.PlayerService.PlayerRemoving:Connect(update)
		self:SetTotal(#Players:GetPlayers())
		return
	end

	task.spawn(function()
		while true do
			self:Refresh()
			task.wait(AGGREGATE_INTERVAL)
		end
	end)
end

OnlineService:OnInit(function(self)
	self:Setup()
end)

OnlineService:OnStart(function(self)
	self.Total = #Players:GetPlayers()

	self.Dependencies.NetService.ClientReady:Connect(function(player)
		self:Publish(player)
	end)

	if self.Remote then
		task.spawn(function()
			while true do
				self:Heartbeat()
				task.wait(HEARTBEAT_INTERVAL)
			end
		end)

		game:BindToClose(function()
			self:Remove()
			self:Release()
		end)
	end

	const roleService = self.Dependencies.ServerRoleService
	roleService:OnReady(function()
		if roleService:IsLobby() then
			self:StartLobby()
		end
	end)
end)

return OnlineService
