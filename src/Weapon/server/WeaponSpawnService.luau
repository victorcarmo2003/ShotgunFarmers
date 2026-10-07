--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local GunRules = require(ServerScriptService.server.Weapon.GunRules)
local Modux = require(ServerScriptService.server.Modux)

const SPAWN_TAG = "WeaponSpawn"
const FALLBACK_TAG = "Farmland"
const PRACTICE_MODE = "Practice"
const SPAWN_INTERVAL = 6
const MAX_ACTIVE = 8
const INITIAL_BURST = 5
const EDGE_MARGIN = 0.15
const POINT_RETRIES = 6
const MIN_SEPARATION = 6

const WeaponSpawnService = Modux.Service("WeaponSpawnService", {
	Require = { "GameStateService", "ServerRoleService" },
	Priority = 300,
})

function WeaponSpawnService:Setup()
	self.Enabled = false :: boolean
	self.Spawned = {} :: { BasePart }
	self.Pool = {} :: { string }
	self.Warned = false :: boolean
end

function WeaponSpawnService:BuildPool()
	for name, gunData in GetGun.All do
		if gunData.Disabled or gunData.SeedModel == "" then
			continue
		end
		if gunData.PoseKind == "Firearm" or gunData.PoseKind == "Throwable" then
			table.insert(self.Pool, name)
		end
	end
	table.sort(self.Pool)
end

local function inWorld(part: Instance): boolean
	return part:IsA("BasePart") and part:IsDescendantOf(workspace)
end

function WeaponSpawnService:Candidates(): { BasePart }
	for _, tag in { SPAWN_TAG, FALLBACK_TAG } do
		const parts: { BasePart } = {}
		for _, instance in CollectionService:GetTagged(tag) do
			if inWorld(instance) then
				table.insert(parts, instance :: BasePart)
			end
		end
		if #parts > 0 then
			return parts
		end
	end
	return {}
end

local function surfacePoint(part: BasePart): Vector3
	const size = part.Size
	const x = (math.random() - 0.5) * size.X * (1 - EDGE_MARGIN * 2)
	const z = (math.random() - 0.5) * size.Z * (1 - EDGE_MARGIN * 2)
	return (part.CFrame * CFrame.new(x, size.Y / 2, z)).Position
end

function WeaponSpawnService:Prune()
	for index = #self.Spawned, 1, -1 do
		if not self.Spawned[index].Parent then
			table.remove(self.Spawned, index)
		end
	end
end

function WeaponSpawnService:FarFromOthers(point: Vector3): boolean
	for _, seed in self.Spawned do
		if (seed.Position - point).Magnitude < MIN_SEPARATION then
			return false
		end
	end
	return true
end

function WeaponSpawnService:SpawnOne(): boolean
	const candidates = self:Candidates()
	if #candidates == 0 or #self.Pool == 0 then
		if not self.Warned then
			self.Warned = true
			warn(`[WeaponSpawnService] mapa sem partes "{SPAWN_TAG}" ou "{FALLBACK_TAG}"; nenhuma arma vai surgir`)
		end
		return false
	end

	for _ = 1, POINT_RETRIES do
		const point = surfacePoint(candidates[math.random(1, #candidates)])
		if self:FarFromOthers(point) then
			const seed = GunRules.PlantAt(point, self.Pool[math.random(1, #self.Pool)])
			if seed then
				table.insert(self.Spawned, seed)
				return true
			end
			return false
		end
	end
	return false
end

function WeaponSpawnService:Fill(limit: number)
	self:Prune()
	local budget = limit
	while budget > 0 and #self.Spawned < MAX_ACTIVE do
		if not self:SpawnOne() then
			return
		end
		budget -= 1
	end
end

function WeaponSpawnService:Clear()
	for _, seed in self.Spawned do
		if seed.Parent then
			seed:Destroy()
		end
	end
	table.clear(self.Spawned)
end

function WeaponSpawnService:Refresh()
	const roles = self.Dependencies.ServerRoleService
	const config = if roles:IsMatch() then roles:GetConfig() else nil
	const active = config ~= nil
		and config.Mode ~= PRACTICE_MODE
		and self.Dependencies.GameStateService:Can("Combat")

	if active == self.Enabled then
		return
	end
	self.Enabled = active

	if active then
		self:Fill(INITIAL_BURST)
	else
		self:Clear()
	end
end

WeaponSpawnService:OnInit(function(self)
	self:Setup()
	self:BuildPool()
end)

WeaponSpawnService:OnStart(function(self)
	self.Dependencies.ServerRoleService:OnReady(function()
		self:Refresh()
	end)

	self.Dependencies.GameStateService:OnChanged(function()
		self:Refresh()
	end)
end)

WeaponSpawnService:OnTick(function(self)
	if self.Enabled then
		self:Fill(1)
	end
end, 1 / SPAWN_INTERVAL)

return WeaponSpawnService
