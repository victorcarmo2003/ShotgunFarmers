--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local UserService = game:GetService("UserService")
local Lync = require(ReplicatedStorage.Packages.Lync)
local RankSettings = require(ReplicatedStorage.shared.Rank.RankSettings)
local Modux = require(ServerScriptService.server.Modux)

type Category = RankSettings.Category
type Entry = RankSettings.Entry
export type Values = { [Category]: number }

const COUNT_MAX = 4294967295
const NAME_MAX = 40
const FALLBACK_NAME = "Player"

const RankService = Modux.Service("RankService", {
	Require = {
		"NetService",
		"PlayerService",
		"ProfileService",
		"ServerRoleService",
	},
	Priority = 630,
})

function RankService:Setup()
	self.Stores = {} :: { [Category]: OrderedDataStore }
	self.Stored = {} :: { [Category]: { Entry } }
	self.Boards = {} :: { [Category]: { Entry } }
	self.Values = {} :: { [Player]: Values }
	self.Saved = {} :: { [Player]: Values }
	self.Names = {} :: { [number]: string }
	self.Disposers = {} :: { [Player]: () -> () }
	self.Warned = {} :: { [string]: boolean }
	self.Lobby = false :: boolean

	for _, category in RankSettings.IDS do
		self.Stored[category] = {}
		self.Boards[category] = {}
	end
end

function RankService:WarnOnce(label: string, reason: any)
	if self.Warned[label] then
		return
	end

	self.Warned[label] = true
	warn(`[RankService] {label} falhou, usando ranking local: {tostring(reason)}`)
end

function RankService:GetStore(category: Category): OrderedDataStore
	const cached = self.Stores[category]
	if cached then
		return cached
	end

	const store = DataStoreService:GetOrderedDataStore(RankSettings.STORE_PREFIX .. category)
	self.Stores[category] = store
	return store
end

function RankService:Read(player: Player): Values?
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile then
		return nil
	end

	const career = profile.Career()
	const xp = math.clamp(math.floor(profile.Xp()), 0, RankSettings.LEVEL_SCALE - 1)
	return {
		Level = profile.Level() * RankSettings.LEVEL_SCALE + xp,
		Wins = math.min(profile.Wins(), COUNT_MAX),
		Kills = math.min(career.Kills, COUNT_MAX),
		Headshots = math.min(career.Headshots, COUNT_MAX),
	}
end

function RankService:SendMine(player: Player)
	const values = self.Values[player]
	const netService = self.Dependencies.NetService
	if not values or not netService:IsRunning() or not netService:IsReady(player) then
		return
	end

	const mine = {}
	for _, category in RankSettings.IDS do
		table.insert(mine, {
			Category = category,
			Value = RankSettings.Display(category, values[category] or 0),
		})
	end
	self.Libs.Net.Rank.Mine:fireClient(player, mine)
end

function RankService:Watch(player: Player)
	if self.Disposers[player] or not self.Dependencies.ProfileService:Get(player) then
		return
	end

	self.Disposers[player] = self.Libs.Charm.effect(function()
		const values = self:Read(player)
		if values then
			self.Values[player] = values
			self:SendMine(player)
		end
	end)
end

function RankService:Unwatch(player: Player)
	const dispose = self.Disposers[player]
	if dispose then
		dispose()
		self.Disposers[player] = nil
	end
end

function RankService:Save(player: Player)
	const values = self.Values[player]
	if not values or player.UserId <= 0 then
		return
	end

	local saved = self.Saved[player]
	if not saved then
		saved = {}
		self.Saved[player] = saved
	end

	const key = tostring(player.UserId)
	for _, category in RankSettings.IDS do
		const value = values[category] or 0
		if value <= 0 or saved[category] == value then
			continue
		end

		const ok, reason = pcall(function()
			self:GetStore(category):SetAsync(key, value)
		end)
		if ok then
			saved[category] = value
		else
			self:WarnOnce("Save", reason)
		end
	end
end

function RankService:SaveAll()
	for player in table.clone(self.Values) do
		self:Save(player)
	end
end

function RankService:Fetch(category: Category): { Entry }?
	const ok, result = pcall(function(): any
		return self:GetStore(category):GetSortedAsync(false, RankSettings.TOP_SIZE):GetCurrentPage()
	end)
	if not ok then
		self:WarnOnce("Fetch", result)
		return nil
	end

	const entries: { Entry } = {}
	for _, item in result :: { any } do
		const userId = tonumber(item.key)
		if userId and typeof(item.value) == "number" then
			table.insert(entries, { UserId = userId, Name = "", Value = item.value })
		end
	end
	return entries
end

function RankService:Merge(category: Category): { Entry }
	const live: { [number]: number } = {}
	for player, values in self.Values do
		const value = values[category] or 0
		if player.Parent == Players and value > 0 then
			live[player.UserId] = value
		end
	end

	const merged: { Entry } = {}
	for _, entry in self.Stored[category] do
		if live[entry.UserId] == nil then
			table.insert(merged, { UserId = entry.UserId, Name = "", Value = entry.Value })
		end
	end
	for userId, value in live do
		table.insert(merged, { UserId = userId, Name = "", Value = value })
	end

	table.sort(merged, function(first: Entry, second: Entry): boolean
		if first.Value ~= second.Value then
			return first.Value > second.Value
		end
		return first.UserId < second.UserId
	end)

	while #merged > RankSettings.TOP_SIZE do
		table.remove(merged)
	end
	return merged
end

function RankService:ResolveNames(userIds: { number })
	const missing: { number } = {}
	for _, userId in userIds do
		if userId > 0 and self.Names[userId] == nil and not Players:GetPlayerByUserId(userId) then
			table.insert(missing, userId)
		end
	end
	if #missing == 0 then
		return
	end

	const ok, infos = pcall(function(): any
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if not ok then
		self:WarnOnce("Names", infos)
		return
	end

	for _, info in infos :: { any } do
		self.Names[info.Id] = info.DisplayName
	end
end

function RankService:NameOf(userId: number): string
	const player = Players:GetPlayerByUserId(userId)
	const name = if player then player.DisplayName else self.Names[userId] or FALLBACK_NAME
	return string.sub(name, 1, NAME_MAX)
end

function RankService:Rebuild()
	const merged: { [Category]: { Entry } } = {}
	const userIds: { number } = {}
	for _, category in RankSettings.IDS do
		const board = self:Merge(category)
		merged[category] = board
		for _, entry in board do
			table.insert(userIds, entry.UserId)
		end
	end

	self:ResolveNames(userIds)

	for category, board in merged do
		for _, entry in board do
			entry.Name = self:NameOf(entry.UserId)
			entry.Value = RankSettings.Display(category, entry.Value)
		end
		self.Boards[category] = board
	end

	self:Publish(self.Dependencies.NetService.Audience)
end

function RankService:Refresh()
	for _, category in RankSettings.IDS do
		const entries = self:Fetch(category)
		if entries then
			self.Stored[category] = entries
		end
	end
	self:Rebuild()
end

function RankService:Publish(to: Lync.Recipient)
	if not self.Dependencies.NetService:IsRunning() then
		return
	end

	for _, category in RankSettings.IDS do
		self.Libs.Net.Rank.Board:fireClient(to, {
			Category = category,
			Entries = self.Boards[category],
		})
	end
end

function RankService:StartLobby()
	self.Lobby = true
	task.spawn(function()
		while true do
			self:Refresh()
			task.wait(RankSettings.REFRESH_INTERVAL)
		end
	end)
end

function RankService:Forget(player: Player)
	self:Unwatch(player)
	task.spawn(function()
		self:Save(player)
		self.Values[player] = nil
		self.Saved[player] = nil
	end)
end

RankService:OnInit(function(self)
	self:Setup()

	self.Dependencies.ProfileService.Loaded:Connect(function(player)
		self:Watch(player)
		if self.Lobby then
			task.spawn(function()
				self:Rebuild()
			end)
		end
	end)

	self.Dependencies.NetService.ClientReady:Connect(function(player)
		self:Watch(player)
		self:SendMine(player)
		self:Publish(player)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Forget(player)
	end)
end)

RankService:OnStart(function(self)
	task.spawn(function()
		while true do
			task.wait(RankSettings.SAVE_INTERVAL)
			self:SaveAll()
		end
	end)

	game:BindToClose(function()
		self:SaveAll()
	end)

	const roleService = self.Dependencies.ServerRoleService
	roleService:OnReady(function()
		if roleService:IsLobby() then
			self:StartLobby()
		end
	end)
end)

return RankService
