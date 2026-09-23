--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Lync = require(ReplicatedStorage.Packages.Lync)
local quietLync = require(ReplicatedStorage.shared.Net.Log)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const NetController = Modux.Controller("NetController", { Priority = 1000 })

function NetController:Setup()
	self.Running = false :: boolean
end

NetController:OnInit(function(self)
	self:Setup()
	quietLync()
end)

NetController:OnStart(function(self)
	Lync.start()
	self.Running = true
	self.Libs.Net.Core.Ready:fireServer()
end)

NetController:OnTick(function(self)
	if not self.Running then
		return
	end
	Lync.flush()
end, 60, -1000)

return NetController
