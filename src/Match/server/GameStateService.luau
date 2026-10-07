--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local GameState = require(ReplicatedStorage.shared.Match.GameState)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

const GameStateService = Modux.Service("GameStateService", {
	Require = { "ServerRoleService", "RoundService" },
	Priority = 880,
})

function GameStateService:Setup()
	self.Resolved = self.Libs.Charm.atom(false) :: Charm.Atom<boolean>
	self.Override = self.Libs.Charm.atom(nil :: GameState.State?) :: Charm.Atom<GameState.State?>
	self.Changed = self.Libs.Signal.new() :: SignalLib.Signal<GameState.State, GameState.State>
	self.State = nil :: (() -> GameState.State)?
end

function GameStateService:Get(): GameState.State
	const state = self.State :: () -> GameState.State
	return state()
end

function GameStateService:Is(state: GameState.State): boolean
	return self:Get() == state
end

function GameStateService:IsInMatch(): boolean
	return GameState.isInMatch(self:Get())
end

function GameStateService:Can(capability: GameState.Capability): boolean
	return GameState.can(self:Get(), capability)
end

function GameStateService:OnChanged(callback: (GameState.State, GameState.State) -> ()): SignalLib.Connection
	return self.Changed:Connect(callback)
end

function GameStateService:Force(state: GameState.State?)
	if not RunService:IsStudio() then
		return
	end

	self.Override(state)
end

GameStateService:OnInit(function(self)
	self:Setup()

	const charm = self.Libs.Charm
	const roleService = self.Dependencies.ServerRoleService
	const roundService = self.Dependencies.RoundService

	self.State = charm.computed(function(): GameState.State
		const override = self.Override()
		if override then
			return override
		end

		if not self.Resolved() then
			return "Loading"
		end

		if roleService:IsRouter() then
			return "Loading"
		end

		if roleService:IsLobby() then
			return "Lobby"
		end

		return GameState.fromRound(roundService.Status())
	end)

	workspace:SetAttribute(GameState.ATTRIBUTE, "Loading")

	charm.subscribe(self.State :: () -> GameState.State, function(state, previous)
		workspace:SetAttribute(GameState.ATTRIBUTE, state)
		self.Changed:Fire(state, previous)
	end)
end)

GameStateService:OnStart(function(self)
	self.Dependencies.ServerRoleService:OnReady(function()
		self.Resolved(true)
	end)
end)

return GameStateService
