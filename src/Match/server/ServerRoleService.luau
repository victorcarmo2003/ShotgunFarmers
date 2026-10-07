--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local GameModes = require(ReplicatedStorage.shared.Match.GameModes)
local Maps = require(ReplicatedStorage.shared.Match.Maps)
local MatchSettings = require(ReplicatedStorage.shared.Match.MatchSettings)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

export type Role = "Lobby" | "Match" | "Router"
export type Config = { Map: string, Mode: string, Ranked: boolean, Private: boolean }

const ServerRoleService = Modux.Service("ServerRoleService", {
	Require = { "MatchRegistryService" },
	Priority = 890,
})

function ServerRoleService:Setup()
	self.Role = "Lobby" :: Role
	self.Config = nil :: Config?
	self.Raw = nil :: { [string]: any }?
	self.Error = nil :: string?
	self.IsReady = false :: boolean
	self.Ready = self.Libs.Signal.new() :: SignalLib.Signal<>
end

function ServerRoleService:GetRole(): Role
	return self.Role
end

function ServerRoleService:GetConfig(): Config?
	return self.Config
end

function ServerRoleService:IsLobby(): boolean
	return self.Role == "Lobby"
end

function ServerRoleService:IsMatch(): boolean
	return self.Role == "Match"
end

function ServerRoleService:IsRouter(): boolean
	return self.Role == "Router"
end

function ServerRoleService:GetRaw(): { [string]: any }?
	return self.Raw
end

function ServerRoleService:OnReady(callback: () -> ())
	if self.IsReady then
		callback()
		return
	end

	self.Ready:Connect(callback)
end

function ServerRoleService:FetchConfig(): any?
	return self.Dependencies.MatchRegistryService:FetchConfig(game.PrivateServerId, true)
end

function ServerRoleService:Validate(raw: any): (Config?, string?)
	if typeof(raw) ~= "table" then
		return nil, "Configuracao da partida nao encontrada"
	end

	const mapName = raw.Map
	const modeName = raw.Mode
	if typeof(mapName) ~= "string" or Maps[mapName] == nil then
		return nil, `Mapa invalido: {tostring(mapName)}`
	end

	if typeof(modeName) ~= "string" or GameModes.Modes[modeName] == nil then
		return nil, `Modo de jogo invalido: {tostring(modeName)}`
	end

	if not table.find(Maps[mapName].Modes, modeName) then
		return nil, `O mapa {mapName} nao suporta o modo {modeName}`
	end

	const mode = GameModes.Modes[modeName]
	const config: Config = {
		Map = mapName,
		Mode = modeName,
		Ranked = if typeof(raw.Ranked) == "boolean" then raw.Ranked else mode.Ranked,
		Private = raw.Private == true,
	}
	return config, nil
end

function ServerRoleService:StringAttribute(name: string, fallback: string): string
	const value = workspace:GetAttribute(name)
	return if typeof(value) == "string" then value else fallback
end

function ServerRoleService:Decide(): (Role, Config?, string?)
	if RunService:IsStudio() then
		const roleName = self:StringAttribute("ForceRole", MatchSettings.StudioRole)
		if roleName ~= "Match" then
			return "Lobby", nil, nil
		end

		const config, reason = self:Validate({
			Map = self:StringAttribute("ForceMap", MatchSettings.StudioMap),
			Mode = self:StringAttribute("ForceMode", MatchSettings.StudioMode),
		})
		if config then
			return "Match", config, nil
		end

		return "Lobby", nil, reason
	end

	if game.PrivateServerId == "" then
		return "Router", nil, nil
	end

	if game.PrivateServerOwnerId ~= 0 then
		return "Lobby", nil, nil
	end

	const fetched, raw = pcall(function()
		return self:FetchConfig()
	end)
	if not fetched then
		return "Router", nil, `Falha ao obter a configuracao da partida: {tostring(raw)}`
	end

	if typeof(raw) == "table" then
		self.Raw = raw
		if raw.Kind == "Lobby" then
			return "Lobby", nil, nil
		end
	end

	const config, reason = self:Validate(raw)
	if config then
		return "Match", config, nil
	end

	self.Raw = nil
	return "Router", nil, reason
end

function ServerRoleService:SetMap(mapName: string)
	const config = self.Config
	if not config or Maps[mapName] == nil then
		return
	end

	config.Map = mapName
	workspace:SetAttribute("MapName", mapName)
end

function ServerRoleService:Publish()
	workspace:SetAttribute("ServerRoleError", self.Error)
	workspace:SetAttribute("MapName", if self.Config then self.Config.Map else nil)
	workspace:SetAttribute("GameMode", if self.Config then self.Config.Mode else nil)
	workspace:SetAttribute("ServerRole", self.Role)
end

function ServerRoleService:Resolve()
	const role, config, errorMessage = self:Decide()

	self.Role = role
	self.Config = config
	self.Error = errorMessage

	if errorMessage then
		warn(`[ServerRoleService] {errorMessage}`)
	end

	self:Publish()
	self.IsReady = true
	self.Ready:Fire()
end

ServerRoleService:OnInit(function(self)
	self:Setup()
end)

ServerRoleService:OnStart(function(self)
	task.spawn(function()
		self:Resolve()
	end)
end)

return ServerRoleService
