--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local GameState = require(ReplicatedStorage.shared.Match.GameState)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const GameStateController = Modux.Controller("GameStateController", { Priority = 950 })

function GameStateController:Setup()
	self.State = Vide.source(GameState.parse(workspace:GetAttribute(GameState.ATTRIBUTE))) :: Vide.Source<GameState.State>
	self.Changed = self.Libs.Signal.new() :: SignalLib.Signal<GameState.State, GameState.State>
end

function GameStateController:Get(): GameState.State
	return self.State()
end

function GameStateController:Is(state: GameState.State): boolean
	return self.State() == state
end

function GameStateController:IsLobby(): boolean
	return self.State() == "Lobby"
end

function GameStateController:IsLoading(): boolean
	return self.State() == "Loading"
end

function GameStateController:IsInMatch(): boolean
	return GameState.isInMatch(self.State())
end

function GameStateController:Can(capability: GameState.Capability): boolean
	return GameState.can(self.State(), capability)
end

function GameStateController:Capability(capability: GameState.Capability): () -> boolean
	return function()
		return GameState.can(self.State(), capability)
	end
end

function GameStateController:Watch(capability: GameState.Capability, callback: (boolean) -> ()): () -> ()
	local last = GameState.can(self.State(), capability)
	task.spawn(callback, last)

	const connection = self.Changed:Connect(function(state)
		const current = GameState.can(state, capability)
		if current == last then
			return
		end

		last = current
		callback(current)
	end)

	return function()
		connection:Disconnect()
	end
end

function GameStateController:Apply(value: any)
	const state = GameState.parse(value)
	const previous = self.State()
	if state == previous then
		return
	end

	self.State(state)
	self.Changed:Fire(state, previous)
end

GameStateController:OnInit(function(self)
	self:Setup()

	workspace:GetAttributeChangedSignal(GameState.ATTRIBUTE):Connect(function()
		self:Apply(workspace:GetAttribute(GameState.ATTRIBUTE))
	end)
end)

return GameStateController
