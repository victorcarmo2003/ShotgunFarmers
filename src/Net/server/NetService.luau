--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Lync = require(ReplicatedStorage.Packages.Lync)
local quietLync = require(ReplicatedStorage.shared.Net.Log)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

const NetService = Modux.Service("NetService", { Priority = 1000 })

function NetService:Setup()
	self.Running = false :: boolean
	self.ClientReady = self.Libs.Signal.new() :: SignalLib.Signal<Player>
	self.Ready = {} :: { [Player]: boolean }
	self.Audience = Lync.group() :: Lync.Group
end

function NetService:IsReady(player: Player): boolean
	return self.Ready[player] == true
end

function NetService:IsRunning(): boolean
	return self.Running
end

NetService:OnInit(function(self)
	self:Setup()
	quietLync()

	self.Libs.Net.Core.Ready:onServer(function(_, player: Player)
		self.Ready[player] = true
		self.Audience:add(player)
		self.ClientReady:Fire(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.Ready[player] = nil
	end)
end)

NetService:OnStart(function(self)
	Lync.start()
	self.Running = true

	game:BindToClose(function()
		self.Running = false
		Lync.close()
	end)
end)

NetService:OnTick(function(self)
	if not self.Running then
		return
	end
	Lync.flush()
end, 60, -1000)

return NetService
