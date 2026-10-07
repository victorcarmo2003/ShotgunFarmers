--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Lync = require(ReplicatedStorage.Packages.Lync)
local Maps = require(ReplicatedStorage.shared.Match.Maps)
local MatchSettings = require(ReplicatedStorage.shared.Match.MatchSettings)
local PracticeCatalog = require(ReplicatedStorage.shared.Practice.PracticeCatalog)
local RoundNet = require(ReplicatedStorage.shared.Round.Net)
local RoundSettings = require(ReplicatedStorage.shared.Round.RoundSettings)
local Modux = require(ServerScriptService.server.Modux)

export type Status = RoundNet.Status

const ORDER: { Status } = { "Starting", "Match", "Intermission", "Vote" }

const RoundService = Modux.Service("RoundService", {
	Require = { "DayNightService", "NetService", "ServerRoleService" },
	Priority = 600,
})

local function secondsFor(status: Status): number
	return (RoundSettings :: { [string]: number })[status]
end

function RoundService:Setup()
	self.Status = self.Libs.Charm.atom("Starting") :: Charm.Atom<Status>
	self.Seconds = self.Libs.Charm.atom(secondsFor("Starting")) :: Charm.Atom<number>
	self.Active = false :: boolean
	self.Holding = false :: boolean
	self.Held = 0 :: number
	self.Skips = {} :: { [string]: () -> boolean }
end

function RoundService:SetSkip(status: Status, shouldSkip: () -> boolean)
	self.Skips[status] = shouldSkip
end

function RoundService:ShouldHold(): boolean
	if not self.Holding then
		return false
	end

	if #Players:GetPlayers() > 0 or self.Held >= MatchSettings.PrivateStartHold then
		self.Holding = false
		return false
	end

	self.Held += 1
	return true
end

function RoundService:Enter(status: Status)
	self.Libs.Charm.batch(function()
		self.Status(status)
		self.Seconds(secondsFor(status))
	end)
end

function RoundService:Advance()
	local index = table.find(ORDER, self.Status()) or 1
	for _ = 1, #ORDER do
		index = index % #ORDER + 1
		const shouldSkip = self.Skips[ORDER[index]]
		if not (shouldSkip and shouldSkip()) then
			break
		end
	end
	self:Enter(ORDER[index])
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
	const roleService = self.Dependencies.ServerRoleService
	roleService:OnReady(function()
		if not roleService:IsMatch() then
			return
		end

		const config = roleService:GetConfig()
		if config and config.Mode == PracticeCatalog.MODE then
			self:Enter("Match")
			return
		end

		self.Holding = config ~= nil and config.Private
		self.Active = true

		if config and Maps[config.Map].DayCycle then
			self.Dependencies.DayNightService:StartCycle()
		end
	end)
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
	if not self.Active or self:ShouldHold() then
		return
	end

	const remaining = self.Seconds() - 1
	if remaining > 0 then
		self.Seconds(remaining)
		return
	end

	self:Advance()
end, 1)

return RoundService
