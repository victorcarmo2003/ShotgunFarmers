--!strict
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Funnels = require(ReplicatedStorage.shared.Analytics.Funnels)
local Modux = require(ServerScriptService.server.Modux)

type FunnelName = Funnels.FunnelName

export type Session = {
	Id: string,
	Step: number,
}

export type TeleportPayload = {
	Sessions: { [string]: { [string]: Session } },
	Marks: { [string]: { [string]: number } },
}

const FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

const FunnelService = Modux.Service("FunnelService", { Require = { "PlayerService" }, Priority = 898 })

function FunnelService:Setup()
	self.Sessions = {} :: { [Player]: { [FunnelName]: Session } }
	self.Verbose = (Funnels.Debug and RunService:IsStudio()) :: boolean
	self.Validators = {} :: { [FunnelName]: (player: Player, step: string, detail: string) -> boolean }
	self.LastClient = {} :: { [Player]: { [string]: number } }
	self.Marks = {} :: { [Player]: { [string]: number } }
end

function FunnelService:Validate(funnel: FunnelName, validator: (player: Player, step: string, detail: string) -> boolean)
	self.Validators[funnel] = validator
end

function FunnelService:FromClient(player: Player, funnel: FunnelName, step: string, detail: string)
	const allowed = Funnels.ClientSteps[funnel]
	if not allowed or not table.find(allowed, step) then
		return
	end

	local last = self.LastClient[player]
	if not last then
		last = {}
		self.LastClient[player] = last
	end
	const key = `{funnel}.{step}`
	const now = os.clock()
	if now - (last[key] or 0) < Funnels.ClientCooldown then
		return
	end
	last[key] = now

	const validator = self.Validators[funnel]
	if validator and not validator(player, step, detail) then
		return
	end

	self:Step(player, funnel, step, if detail ~= "" then { detail } else nil)
end

function FunnelService:Fields(fields: { string }?): { [string]: any }?
	if not fields or #fields == 0 then
		return nil
	end

	const result: { [string]: any } = {}
	for index = 1, math.min(#fields, Funnels.MaxFields) do
		result[FIELD_KEYS[index]] = string.sub(fields[index], 1, Funnels.FieldLength)
	end
	return result
end

function FunnelService:Log(label: string, send: () -> ())
	if self.Verbose then
		print(`[FunnelService] {label}`)
	end

	const ok, reason = pcall(send)
	if not ok then
		warn(`[FunnelService] {label} falhou: {tostring(reason)}`)
	end
end

function FunnelService:Get(player: Player, funnel: FunnelName): Session?
	const sessions = self.Sessions[player]
	return if sessions then sessions[funnel] else nil
end

function FunnelService:Begin(player: Player, funnel: FunnelName): string
	return self:Resume(player, funnel, HttpService:GenerateGUID(false), 0)
end

function FunnelService:Resume(player: Player, funnel: FunnelName, id: string, step: number): string
	if not player.Parent then
		return id
	end

	local sessions = self.Sessions[player]
	if not sessions then
		sessions = {}
		self.Sessions[player] = sessions
	end
	sessions[funnel] = { Id = id, Step = step }
	return id
end

function FunnelService:Current(player: Player, funnel: FunnelName): Session?
	const session = self:Get(player, funnel)
	if not session then
		return nil
	end
	return { Id = session.Id, Step = session.Step }
end

function FunnelService:Mark(player: Player, key: string)
	if not player.Parent then
		return
	end

	local marks = self.Marks[player]
	if not marks then
		marks = {}
		self.Marks[player] = marks
	end
	marks[key] = os.time()
end

function FunnelService:TakeMark(player: Player, key: string): number?
	const marks = self.Marks[player]
	const at = if marks then marks[key] else nil
	if marks then
		marks[key] = nil
	end
	return at
end

function FunnelService:Export(players: { Player }, funnels: { FunnelName }): TeleportPayload
	const payload: TeleportPayload = { Sessions = {}, Marks = {} }
	for _, funnel in funnels do
		const entries: { [string]: Session } = {}
		for _, player in players do
			const session = self:Current(player, funnel)
			if session then
				entries[tostring(player.UserId)] = session
			end
		end
		payload.Sessions[funnel] = entries
	end

	for _, player in players do
		const marks = self.Marks[player]
		if marks and next(marks) then
			payload.Marks[tostring(player.UserId)] = table.clone(marks)
		end
	end
	return payload
end

function FunnelService:Import(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	const userKey = tostring(player.UserId)
	const sessions = payload.Sessions
	if typeof(sessions) == "table" then
		for funnel, steps in Funnels.Steps do
			const entries = sessions[funnel]
			const entry = if typeof(entries) == "table" then entries[userKey] else nil
			if typeof(entry) == "table" and typeof(entry.Id) == "string" and typeof(entry.Step) == "number" then
				self:Resume(player, funnel, string.sub(entry.Id, 1, 64), math.clamp(math.floor(entry.Step), 0, #steps))
			end
		end
	end

	const marks = payload.Marks
	const entry = if typeof(marks) == "table" then marks[userKey] else nil
	if typeof(entry) ~= "table" then
		return
	end
	for key, at in entry do
		if typeof(key) == "string" and typeof(at) == "number" then
			local own = self.Marks[player]
			if not own then
				own = {}
				self.Marks[player] = own
			end
			own[string.sub(key, 1, 32)] = at
		end
	end
end

function FunnelService:End(player: Player, funnel: FunnelName)
	const sessions = self.Sessions[player]
	if sessions then
		sessions[funnel] = nil
	end
end

function FunnelService:Step(player: Player, funnel: FunnelName, stepName: string, fields: { string }?): boolean
	const steps = Funnels.Steps[funnel]
	const index = table.find(steps, stepName)
	if not index then
		warn(`[FunnelService] passo desconhecido {funnel}.{stepName}`)
		return false
	end

	local session = self:Get(player, funnel)
	if index == 1 and (not session or session.Step >= 1) then
		self:Begin(player, funnel)
		session = self:Get(player, funnel)
	end
	if not session or index <= session.Step then
		return false
	end

	session.Step = index
	const id = session.Id
	const custom = self:Fields(fields)
	self:Log(`{player.Name} {funnel} {index}/{#steps} {stepName}`, function()
		AnalyticsService:LogFunnelStepEvent(player, funnel, id, index, stepName, custom)
	end)

	if index == #steps then
		self:End(player, funnel)
	end
	return true
end

function FunnelService:Drop(player: Player, funnel: FunnelName, reason: string, fields: { string }?): boolean
	const session = self:Get(player, funnel)
	if not session then
		return false
	end

	const lastStep = Funnels.Steps[funnel][session.Step] or "None"
	const values: { string } = { reason, lastStep }
	if fields and fields[1] then
		table.insert(values, fields[1])
	end
	self:End(player, funnel)
	self:Event(player, `{funnel}Drop`, 1, values)
	return true
end

function FunnelService:Event(player: Player, name: string, value: number?, fields: { string }?)
	const custom = self:Fields(fields)
	self:Log(`{player.Name} event {name} {if value then value else ""}`, function()
		AnalyticsService:LogCustomEvent(player, name, value, custom)
	end)
end

FunnelService:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Analytics.Track:onServer(function(data, player)
		self:FromClient(player, data.Funnel, data.Step, data.Detail)
	end)
end)

FunnelService:OnStart(function(self)
	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.Sessions[player] = nil
		self.LastClient[player] = nil
		self.Marks[player] = nil
	end)
end)

return FunnelService
