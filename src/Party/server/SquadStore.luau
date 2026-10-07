--!strict
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PartySettings = require(ReplicatedStorage.shared.Party.PartySettings)
local SquadRecord = require(ReplicatedStorage.shared.Party.SquadRecord)
local Modux = require(ServerScriptService.server.Modux)

type Record = SquadRecord.Record
type Status = SquadRecord.Status

export type JoinResult = "Ok" | "Missing" | "Full" | "Error"

local function tokenKey(key: string, userId: number): string
	return `{key}:{userId}`
end

const warned: { [string]: boolean } = {}
local tokens: MemoryStoreHashMap? = nil

local function warnOnce(label: string, reason: any)
	if warned[label] then
		return
	end

	warned[label] = true
	warn(`[SquadStore] {label}: {tostring(reason)}`)
end

local function getTokens(): MemoryStoreHashMap
	if not tokens then
		tokens = MemoryStoreService:GetHashMap(PartySettings.TokenMapName)
	end

	return tokens :: MemoryStoreHashMap
end

const SquadStore = Modux.Service("SquadStore", {
	Require = { "PresenceService" },
	Priority = 835,
})

function SquadStore:Setup()
	self.Map = nil :: MemoryStoreHashMap?
end

function SquadStore:GetMap(): MemoryStoreHashMap
	if not self.Map then
		self.Map = MemoryStoreService:GetHashMap(PartySettings.SquadMapName)
	end

	return self.Map :: MemoryStoreHashMap
end

function SquadStore:Get(key: string): (boolean, Record?)
	if key == "" then
		return true, nil
	end

	const ok, raw = pcall(function(): any
		return self:GetMap():GetAsync(key)
	end)
	if not ok then
		warnOnce("Get", raw)
		return false, nil
	end
	return true, SquadRecord.sanitize(raw)
end

function SquadStore:GrantToken(key: string, userId: number)
	const ok, reason = pcall(function()
		getTokens():SetAsync(tokenKey(key, userId), os.time(), PartySettings.TokenTTL)
	end)
	if not ok then
		warnOnce("GrantToken", reason)
	end
end

function SquadStore:HasToken(key: string, userId: number): boolean
	const ok, raw = pcall(function(): any
		return getTokens():GetAsync(tokenKey(key, userId))
	end)
	if not ok then
		warnOnce("HasToken", raw)
		return false
	end
	return typeof(raw) == "number" and os.time() - raw <= PartySettings.TokenTTL
end

function SquadStore:Update(key: string, transform: (Record?) -> Record?): (boolean, Record?)
	local written: Record? = nil
	local lastError: any = nil

	for attempt = 1, PartySettings.StoreAttempts do
		const ok, reason = pcall(function()
			written = nil
			self:GetMap():UpdateAsync(key, function(raw: any): any
				const result = transform(SquadRecord.sanitize(raw))
				written = result
				return result
			end, PartySettings.SquadTTL)
		end)
		if ok then
			return true, written
		end

		lastError = reason
		if attempt < PartySettings.StoreAttempts then
			task.wait(PartySettings.StoreBackoff * 2 ^ (attempt - 1))
		end
	end

	warnOnce("Update", lastError)
	return false, nil
end

function SquadStore:Notify(record: Record?, key: string)
	if not record or record.Job == "" then
		return
	end

	self.Dependencies.PresenceService:Send(record.Job, { K = "Squad", Squad = key })
end

function SquadStore:AddMember(key: string, player: Player, status: Status): (JoinResult, Record?)
	local result: JoinResult = "Missing"
	local snapshot: Record? = nil

	const ok = self:Update(key, function(current: Record?): Record?
		snapshot = nil
		if not current or #current.Members == 0 then
			result = "Missing"
			return nil
		end

		const now = os.time()
		const existing = SquadRecord.find(current, player.UserId)
		if existing then
			existing.Status = status
			existing.Joined = now
		elseif #current.Members >= PartySettings.MaxSize then
			result = "Full"
			return nil
		else
			table.insert(current.Members, {
				Id = player.UserId,
				Name = string.sub(player.DisplayName, 1, 40),
				Status = status,
				Joined = now,
			})
		end

		current.At = now
		result = "Ok"
		snapshot = current
		return current
	end)

	if not ok then
		return "Error", nil
	end

	if result == "Ok" then
		self:Notify(snapshot, key)
	end
	return result, snapshot
end

function SquadStore:RemoveMember(key: string, userId: number)
	if key == "" then
		return
	end

	const ok, record = self:Update(key, function(current: Record?): Record?
		if current and SquadRecord.remove(current, userId) then
			return current
		end
		return nil
	end)
	if ok then
		self:Notify(record, key)
	end
end

function SquadStore:Touch(key: string)
	self:Update(key, function(current: Record?): Record?
		return current
	end)
end

SquadStore:OnInit(function(self)
	self:Setup()
end)

return SquadStore
