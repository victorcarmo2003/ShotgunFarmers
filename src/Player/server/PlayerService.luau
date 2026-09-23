--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

const PlayerService = Modux.Service("PlayerService", { Priority = 900 })

function PlayerService:Setup()
	self.PlayerAdded = self.Libs.Signal.new() :: SignalLib.Signal<Player>
	self.PlayerRemoving = self.Libs.Signal.new() :: SignalLib.Signal<Player>
	self.CharacterAdded = self.Libs.Signal.new() :: SignalLib.Signal<Player, Model>
	self.CharacterRemoving = self.Libs.Signal.new() :: SignalLib.Signal<Player, Model>
	self.Connections = {} :: { [Player]: { RBXScriptConnection } }
end

function PlayerService:Watch(player: Player)
	if self.Connections[player] ~= nil then
		return
	end

	const bucket = {}
	self.Connections[player] = bucket

	table.insert(
		bucket,
		player.CharacterAdded:Connect(function(character)
			self.CharacterAdded:Fire(player, character)
		end)
	)
	table.insert(
		bucket,
		player.CharacterRemoving:Connect(function(character)
			self.CharacterRemoving:Fire(player, character)
		end)
	)

	self.PlayerAdded:Fire(player)

	const character = player.Character
	if character then
		self.CharacterAdded:Fire(player, character)
	end
end

function PlayerService:Forget(player: Player)
	self.PlayerRemoving:Fire(player)

	const bucket = self.Connections[player]
	if not bucket then
		return
	end
	for _, connection in bucket do
		connection:Disconnect()
	end
	self.Connections[player] = nil
end

PlayerService:OnInit(function(self)
	self:Setup()

	Players.PlayerAdded:Connect(function(player)
		self:Watch(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Forget(player)
	end)
end)

PlayerService:OnStart(function(self)
	for _, player in Players:GetPlayers() do
		self:Watch(player)
	end
end)

return PlayerService
