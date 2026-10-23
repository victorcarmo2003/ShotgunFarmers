--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const HUMANS_GOAL = 2

const RoomFunnelService = Modux.Service("RoomFunnelService", {
	Require = { "FunnelService", "MatchStatsService", "PlayerService", "ServerRoleService" },
	Priority = 600,
})

function RoomFunnelService:Setup()
	self.Active = false :: boolean
	self.Started = false :: boolean
end

function RoomFunnelService:StepAll(step: string, fields: { string }?)
	for _, player in Players:GetPlayers() do
		self.Dependencies.FunnelService:Step(player, "PrivateRoom", step, fields)
	end
end

function RoomFunnelService:OnJoined()
	const count = #Players:GetPlayers()
	if count >= HUMANS_GOAL then
		self:StepAll("OtherJoined", { tostring(count) })
	end
end

function RoomFunnelService:OnMatchStarted()
	if self.Started then
		return
	end
	self.Started = true

	const count = #Players:GetPlayers()
	self:StepAll("MatchStarted", { tostring(count) })
	if count >= HUMANS_GOAL then
		self:StepAll("TwoHumans", { tostring(count) })
	end
end

function RoomFunnelService:Activate()
	const roles = self.Dependencies.ServerRoleService
	const raw = roles:GetRaw()
	self.Active = roles:IsMatch() and raw ~= nil and typeof(raw.Code) == "string"
	if self.Active then
		task.defer(function()
			self:OnJoined()
		end)
	end
end

RoomFunnelService:OnInit(function(self)
	self:Setup()
end)

RoomFunnelService:OnStart(function(self)
	self.Dependencies.ServerRoleService:OnReady(function()
		self:Activate()
	end)

	self.Dependencies.PlayerService.PlayerAdded:Connect(function()
		if self.Active then
			task.defer(function()
				self:OnJoined()
			end)
		end
	end)

	self.Dependencies.MatchStatsService.MatchStarted:Connect(function()
		if self.Active then
			self:OnMatchStarted()
		end
	end)
end)

return RoomFunnelService
