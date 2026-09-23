--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const NO_ZONE = ""

const ZoneService = Modux.Service("ZoneService", {
	Require = { "ProfileService", "PlayerService" },
	Priority = 620,
})

function ZoneService:Setup()
	self.Zones = {} :: { [Player]: string }
end

function ZoneService:Publish(player: Player, zone: string)
	if not self.Dependencies.ProfileService:Get(player) then
		return
	end

	self.Dependencies.ProfileService:Update(player, { CurrentZone = zone })
end

function ZoneService:Enter(player: Player, zone: string)
	if self.Zones[player] == zone then
		return
	end

	self.Zones[player] = zone
	self:Publish(player, zone)
end

function ZoneService:Leave(player: Player, zone: string)
	if self.Zones[player] ~= zone then
		return
	end

	self.Zones[player] = nil
	self:Publish(player, NO_ZONE)
end

ZoneService:OnInit(function(self)
	self:Setup()

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player: Player)
		self.Zones[player] = nil
	end)
end)

return ZoneService
