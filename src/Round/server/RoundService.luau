--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Lync = require(ReplicatedStorage.Packages.Lync)
local RoundNet = require(ReplicatedStorage.shared.Round.Net)
local RoundSettings = require(ReplicatedStorage.shared.Round.RoundSettings)
local Modux = require(ServerScriptService.server.Modux)

export type Status = RoundNet.Status

const ORDER: { Status } = { "Starting", "Match", "Intermission", "Vote" }

const RoundService = Modux.Service("RoundService", { Require = { "DayNightService", "NetService" }, Priority = 600 })

local function secondsFor(status: Status): number
	return (RoundSettings :: { [string]: number })[status]
end

function RoundService:Setup()
	self.Status = self.Libs.Charm.atom("Starting") :: Charm.Atom<Status>
	self.Seconds = self.Libs.Charm.atom(secondsFor("Starting")) :: Charm.Atom<number>
end

function RoundService:Enter(status: Status)
	self.Libs.Charm.batch(function()
		self.Status(status)
		self.Seconds(secondsFor(status))
	end)
end

function RoundService:Advance()
	const index = table.find(ORDER, self.Status()) or 1
	self:Enter(ORDER[index % #ORDER + 1])
end

function RoundService:Publish(to: Lync.Recipient)
	if not self.Dependencies.NetService:IsRunning() then
		return
	end

	self.Libs.Net.Round.State:fireClient(to, {
		Status = self.Status(),
		Seconds = self.Seconds(),
	})
end

RoundService:OnInit(function(self)
	self:Setup()
end)

RoundService:OnStart(function(self)
	self.Dependencies.DayNightService:StartCycle()
end)

RoundService:OnStart(function(self)
	self.Dependencies.NetService.ClientReady:Connect(function(player)
		self:Publish(player)
	end)

	self.Libs.Charm.effect(function()
		self:Publish(self.Dependencies.NetService.Audience)
	end)
end)

RoundService:OnTick(function(self)
	const remaining = self.Seconds() - 1
	if remaining > 0 then
		self.Seconds(remaining)
		return
	end

	self:Advance()
end, 1)

return RoundService
