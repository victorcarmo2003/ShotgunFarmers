--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

type Counter = {
	Name: string,
	Fields: { string },
	Value: number,
}

const SHOT_SOURCE = "Shot"
const KILL_GOAL = 3

const PlantLoopService = Modux.Service("PlantLoopService", {
	Require = { "FunnelService", "PlayerService", "MatchStatsService", "PracticeService", "ServerRoleService" },
	Priority = 600,
})

function PlantLoopService:Setup()
	self.Started = {} :: { [Player]: boolean }
	self.Owned = {} :: { [Player]: { [string]: boolean } }
	self.Kills = {} :: { [Player]: number }
	self.Counts = {} :: { [Player]: { [string]: Counter } }
end

function PlantLoopService:Enabled(): boolean
	return self.Dependencies.ServerRoleService:IsMatch() and not self.Dependencies.PracticeService:IsPractice()
end

function PlantLoopService:Step(player: Player, step: string, fields: { string }?)
	self.Dependencies.FunnelService:Step(player, "PlantLoop", step, fields)
end

function PlantLoopService:Count(player: Player, name: string, fields: { string })
	local counters = self.Counts[player]
	if not counters then
		counters = {}
		self.Counts[player] = counters
	end

	const key = `{name}|{table.concat(fields, "|")}`
	const counter = counters[key]
	if counter then
		counter.Value += 1
	else
		counters[key] = { Name = name, Fields = fields, Value = 1 }
	end
end

function PlantLoopService:Flush(player: Player)
	const counters = self.Counts[player]
	if not counters then
		return
	end

	self.Counts[player] = nil
	for _, counter in counters do
		self.Dependencies.FunnelService:Event(player, counter.Name, counter.Value, counter.Fields)
	end
end

function PlantLoopService:Planter(planterId: number): Player?
	if planterId <= 0 then
		return nil
	end
	return Players:GetPlayerByUserId(planterId)
end

function PlantLoopService:Respawned(player: Player, starting: string?)
	self.Owned[player] = nil
	if not starting or self.Started[player] or not self:Enabled() then
		return
	end

	self.Started[player] = true
	self.Kills[player] = 0
	self:Step(player, "SpawnedWithWeapon", { starting })
end

function PlantLoopService:Planted(gunName: string, source: string, planterId: number)
	const planter = self:Planter(planterId)
	if not planter or not self:Enabled() then
		return
	end

	self:Count(planter, "SeedPlanted", { source, gunName })
	if source == SHOT_SOURCE then
		self:Step(planter, "FirstSeedPlanted", { gunName })
	end
end

function PlantLoopService:Harvestable(_gunName: string, source: string, planterId: number)
	const planter = self:Planter(planterId)
	if planter and source == SHOT_SOURCE and self:Enabled() then
		self:Step(planter, "SeedHarvestable")
	end
end

function PlantLoopService:Expired(gunName: string, source: string, planterId: number)
	const planter = self:Planter(planterId)
	if planter and self:Enabled() then
		self:Count(planter, "SeedExpired", { source, gunName })
	end
end

function PlantLoopService:Harvested(player: Player, gunName: string, source: string, planterId: number, granted: boolean)
	if not self:Enabled() then
		return
	end

	const relation = if planterId <= 0 then "World" elseif planterId == player.UserId then "Own" else "Other"
	self:Count(player, "SeedHarvested", { source, gunName, relation })
	if relation == "Other" then
		const planter = self:Planter(planterId)
		if planter then
			self:Count(planter, "SeedLostToOther", { gunName })
		end
	end

	self:Step(player, "Harvested", { source })
	if not granted then
		return
	end

	local owned = self.Owned[player]
	if not owned then
		owned = {}
		self.Owned[player] = owned
	end
	owned[gunName] = true
	self:Step(player, "HarvestedNewWeapon", { gunName })
end

function PlantLoopService:OnKill(killer: any)
	if typeof(killer) ~= "Instance" then
		return
	end

	const instance = killer :: Instance
	if not instance:IsA("Player") then
		return
	end

	const player = instance :: Player
	const owned = self.Owned[player]
	const equipment = self.Components.Equipment:Get(player)
	const gunName = if equipment then equipment.Equipped else nil
	if not owned or not gunName or not owned[gunName] then
		return
	end

	const kills = (self.Kills[player] or 0) + 1
	self.Kills[player] = kills
	self:Step(player, "KillWithHarvested", { gunName })
	if kills >= KILL_GOAL then
		self:Step(player, "ThreeHarvestedKills")
	end
end

function PlantLoopService:Forget(player: Player)
	self:Flush(player)
	self.Dependencies.FunnelService:End(player, "PlantLoop")
	self.Started[player] = nil
	self.Owned[player] = nil
	self.Kills[player] = nil
end

PlantLoopService:OnInit(function(self)
	self:Setup()
end)

PlantLoopService:OnStart(function(self)
	const stats = self.Dependencies.MatchStatsService
	stats.Killed:Connect(function(killer)
		self:OnKill(killer)
	end)

	stats.MatchEnded:Connect(function()
		for _, player in Players:GetPlayers() do
			self:Forget(player)
		end
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Forget(player)
	end)
end)

return PlantLoopService
