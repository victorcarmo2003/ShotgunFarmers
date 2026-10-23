--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
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
const PROBE_CLEARANCE = 20
const MIN_SURFACE_NORMAL = 0.6

const probeParams = RaycastParams.new()
probeParams.FilterType = Enum.RaycastFilterType.Exclude

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

local function worldExtents(part: BasePart): Vector3
	const half = part.Size / 2
	const cf = part.CFrame
	const right, up, back = cf.RightVector, cf.UpVector, -cf.LookVector
	return Vector3.new(
		math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(back.X) * half.Z,
		math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(back.Y) * half.Z,
		math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(back.Z) * half.Z
	)
end

local function isSpawnSurface(instance: Instance): boolean
	return CollectionService:HasTag(instance, SPAWN_TAG) or CollectionService:HasTag(instance, FALLBACK_TAG)
end

local function surfacePoint(part: BasePart): Vector3?
	const extents = worldExtents(part)
	const center = part.Position
	const x = center.X + (math.random() * 2 - 1) * extents.X * (1 - EDGE_MARGIN * 2)
	const z = center.Z + (math.random() * 2 - 1) * extents.Z * (1 - EDGE_MARGIN * 2)
	const top = center.Y + extents.Y + PROBE_CLEARANCE

	const ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	const seeds = workspace:FindFirstChild("Seeds")
	if seeds then
		table.insert(ignore, seeds)
	end
	probeParams.FilterDescendantsInstances = ignore

	const result = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -(extents.Y * 2 + PROBE_CLEARANCE * 2), 0), probeParams)
	if not result or not isSpawnSurface(result.Instance) or result.Normal.Y < MIN_SURFACE_NORMAL then
		return nil
	end
	return result.Position
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
		if point and self:FarFromOthers(point) then
			const seed = GunRules.PlantAt(point, self.Pool[math.random(1, #self.Pool)], "WeaponSpawn")
			if seed then
				table.insert(self.Spawned, seed)
				return true
			end
			return false
		end
	end
	return false
end

function WeaponSpawnService:IsActive(): boolean
	return self.Enabled
end

function WeaponSpawnService:RandomPoint(avoid: { BasePart }, separation: number): Vector3?
	const candidates = self:Candidates()
	if #candidates == 0 then
		return nil
	end

	for _ = 1, POINT_RETRIES do
		const point = surfacePoint(candidates[math.random(1, #candidates)])
		if not point or not self:FarFromOthers(point) then
			continue
		end

		local clear = true
		for _, part in avoid do
			if (part.Position - point).Magnitude < separation then
				clear = false
				break
			end
		end
		if clear then
			return point
		end
	end
	return nil
end

function WeaponSpawnService:SpawnExtra(): BasePart?
	const candidates = self:Candidates()
	if #candidates == 0 or #self.Pool == 0 then
		return nil
	end

	for _ = 1, POINT_RETRIES do
		const point = surfacePoint(candidates[math.random(1, #candidates)])
		if point and self:FarFromOthers(point) then
			const seed = GunRules.PlantAt(point, self.Pool[math.random(1, #self.Pool)], "CropDrop")
			if seed then
				table.insert(self.Spawned, seed)
			end
			return seed
		end
	end
	return nil
end

function WeaponSpawnService:CropDrop(duration: number, interval: number, maxSeeds: number): boolean
	if not self.Enabled then
		return false
	end

	task.spawn(function()
		const endsAt = os.clock() + duration
		local spawned = 0
		while self.Enabled and os.clock() < endsAt and spawned < maxSeeds do
			if self:SpawnExtra() then
				spawned += 1
			end
			task.wait(interval)
		end
	end)
	return true
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
