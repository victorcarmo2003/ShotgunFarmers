--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")
local MatchmakingSettings = require(ReplicatedStorage.shared.Matchmaking.MatchmakingSettings)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

export type TeleportData = { [string]: any }
export type Reservation = { AccessCode: string, ServerId: string }

local function describe(players: { Player }): string
	const names: { string } = {}
	for _, player in players do
		table.insert(names, player.Name)
	end
	return table.concat(names, ", ")
end

local function presentOf(players: { Player }): { Player }
	const present: { Player } = {}
	for _, player in players do
		if player:IsDescendantOf(Players) then
			table.insert(present, player)
		end
	end
	return present
end

local function buildOptions(accessCode: string?, data: TeleportData?): TeleportOptions
	const options = Instance.new("TeleportOptions")
	if accessCode then
		options.ReservedServerAccessCode = accessCode
	end
	if data then
		options:SetTeleportData(data)
	end
	return options
end

const TeleportGateway = Modux.Service("TeleportGateway", {
	Require = { "PlayerService" },
	Priority = 870,
})

function TeleportGateway:Setup()
	self.Simulated = RunService:IsStudio() :: boolean
	self.Retries = {} :: { [Player]: number }
	self.InFlight = {} :: { [Player]: boolean }
	self.Failed = self.Libs.Signal.new() :: SignalLib.Signal<Player, string>
end

function TeleportGateway:IsSimulated(): boolean
	return self.Simulated
end

function TeleportGateway:IsTeleporting(player: Player): boolean
	return self.InFlight[player] == true
end

function TeleportGateway:Reserve(): (Reservation?, string?)
	if self.Simulated then
		const id = HttpService:GenerateGUID(false)
		print(`[TeleportGateway] Studio: ReserveServer simulado -> studio-{id}`)
		return { AccessCode = `studio-access-{id}`, ServerId = `studio-{id}` }, nil
	end

	const reserved, accessCode, serverId = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not reserved then
		return nil, `Falha ao reservar servidor: {tostring(accessCode)}`
	end

	return { AccessCode = accessCode, ServerId = serverId }, nil
end

function TeleportGateway:Teleport(players: { Player }, accessCode: string?, data: TeleportData?): (boolean, string?)
	const present = presentOf(players)
	if #present == 0 then
		return false, "Nenhum jogador para teleportar"
	end

	if self.Simulated then
		print(
			`[TeleportGateway] Studio: teleporte simulado de [{describe(present)}] para {accessCode or "place"} com {HttpService:JSONEncode(data or {})}`
		)
		return true, nil
	end

	const options = buildOptions(accessCode, data)
	local lastError = ""
	for attempt = 0, MatchmakingSettings.TeleportRetries do
		const current = presentOf(present)
		if #current == 0 then
			return false, "Nenhum jogador para teleportar"
		end

		for _, player in current do
			self.Retries[player] = 0
			self.InFlight[player] = true
		end

		const sent, reason = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, current, options)
		end)
		if sent then
			return true, nil
		end

		for _, player in current do
			self.InFlight[player] = nil
		end

		lastError = tostring(reason)
		if attempt < MatchmakingSettings.TeleportRetries then
			task.wait(1)
		end
	end

	return false, `Falha no teleporte: {lastError}`
end

function TeleportGateway:HandleInitFailed(player: Player, message: string, options: Instance?)
	const retries = self.Retries[player]
	if retries ~= nil and retries < MatchmakingSettings.TeleportRetries and options and options:IsA("TeleportOptions") then
		self.Retries[player] = retries + 1
		task.wait(1)
		if not player:IsDescendantOf(Players) then
			return
		end

		const sent = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
		if sent then
			return
		end
	end

	self.Retries[player] = nil
	self.InFlight[player] = nil
	self.Failed:Fire(player, `Falha no teleporte: {message}`)
end

TeleportGateway:OnInit(function(self)
	self:Setup()

	TeleportService.TeleportInitFailed:Connect(function(player, _result, message, _placeId, options)
		task.spawn(function()
			self:HandleInitFailed(player, message, options)
		end)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.Retries[player] = nil
		self.InFlight[player] = nil
	end)
end)

return TeleportGateway
