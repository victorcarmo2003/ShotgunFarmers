--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MatchSettings = require(ReplicatedStorage.shared.Match.MatchSettings)
local Modux = require(ServerScriptService.server.Modux)

const SPAWN_WAIT_TIMEOUT = 2

type Sample = {
	point: Vector3,
	part: BasePart,
}

type Resolved = {
	cframe: CFrame,
	valid: boolean,
	hasGround: boolean,
}

type RecentSpawn = {
	pos: Vector3,
	time: number,
}

const SpawnService = Modux.Service("SpawnService", {
	Require = { "PlayerService", "ServerRoleService", "EnvironmentService", "TeamService" },
	Priority = 780,
})

function SpawnService:Setup()
	self.Enabled = false :: boolean
	self.Pending = {} :: { [Player]: boolean }
	self.Spawning = {} :: { [Player]: boolean }
	self.Epoch = {} :: { [Player]: number }
	self.Slots = {} :: { [number]: Player }
	self.SlotOf = {} :: { [Player]: number }
	self.Destination = {} :: { [Player]: CFrame }
	self.SlotProvider = nil :: ((Player) -> number?)?

	const probe = Instance.new("Part")
	probe.Size = MatchSettings.SpawnProbeSize
	probe.Anchored = true
	probe.CanCollide = false
	probe.CanQuery = false
	probe.CanTouch = false
	self.Probe = probe :: Part

	const rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.RespectCanCollide = true
	self.RayParams = rayParams :: RaycastParams

	const overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.RespectCanCollide = true
	self.OverlapParams = overlapParams :: OverlapParams

	self.RecentSpawns = {} :: { RecentSpawn }
end

function SpawnService:GetSpawnParts(): { BasePart }
	const environment = self.Dependencies.EnvironmentService
	const parts: { BasePart } = {}
	for _, part in environment:GetFFASpawns() do
		table.insert(parts, part)
	end
	for _, teamName in MatchSettings.TeamNames do
		const part = environment:GetTeamSpawn(teamName)
		if part then
			table.insert(parts, part)
		end
	end
	return parts
end

function SpawnService:ApplyFilter()
	const filter: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(filter, other.Character)
		end
	end
	for _, part in self:GetSpawnParts() do
		table.insert(filter, part)
	end
	self.RayParams.FilterDescendantsInstances = filter
	self.OverlapParams.FilterDescendantsInstances = filter
end

function SpawnService:SampleCandidates(parts: { BasePart }): { Sample }
	const samples: { Sample } = {}
	for _, part in parts do
		for _ = 1, MatchSettings.SpawnSamplesPerPart do
			const offsetX = (math.random() - 0.5) * part.Size.X
			const offsetZ = (math.random() - 0.5) * part.Size.Z
			const top = part.CFrame * CFrame.new(offsetX, part.Size.Y / 2, offsetZ)
			table.insert(samples, { point = top.Position, part = part })
		end
	end

	for index = #samples, 2, -1 do
		const swap = math.random(1, index)
		samples[index], samples[swap] = samples[swap], samples[index]
	end

	for index = #samples, MatchSettings.SpawnMaxAttempts + 1, -1 do
		samples[index] = nil
	end

	return samples
end

function SpawnService:Resolve(point: Vector3, part: BasePart): Resolved?
	const origin = point + Vector3.new(0, MatchSettings.SpawnRayHeight, 0)
	const hit = workspace:Raycast(origin, Vector3.new(0, -MatchSettings.SpawnRayDepth, 0), self.RayParams)
	if not hit then
		return nil
	end

	const ground = hit.Position
	const lift = MatchSettings.SpawnProbeLift
	const probe = self.Probe
	probe.CFrame = CFrame.new(ground + Vector3.new(0, lift + MatchSettings.SpawnProbeSize.Y / 2, 0))

	local valid = #workspace:GetPartsInPart(probe, self.OverlapParams) == 0

	if valid then
		const ceiling = workspace:Raycast(
			ground + Vector3.new(0, lift + 0.5, 0),
			Vector3.new(0, MatchSettings.SpawnCeilingHeight, 0),
			self.RayParams
		)
		if ceiling then
			valid = false
		end
	end

	const _, yaw = part.CFrame:ToOrientation()
	return {
		cframe = CFrame.new(ground + Vector3.new(0, MatchSettings.SpawnFootOffset, 0)) * CFrame.Angles(0, yaw, 0),
		valid = valid,
		hasGround = true,
	}
end

function SpawnService:GetEnemyPositions(player: Player): { Vector3 }
	const team = self.Dependencies.TeamService:GetTeam(player)
	const positions: { Vector3 } = {}
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		if team and self.Dependencies.TeamService:GetTeam(other) == team then
			continue
		end

		const character = other.Character
		const humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			table.insert(positions, root.Position)
		end
	end
	return positions
end

function SpawnService:PruneRecent()
	const now = os.clock()
	const kept: { RecentSpawn } = {}
	for _, entry in self.RecentSpawns do
		if now - entry.time <= MatchSettings.SpawnRecentSeconds then
			table.insert(kept, entry)
		end
	end
	self.RecentSpawns = kept
end

function SpawnService:PickSpawn(player: Player, parts: { BasePart }): CFrame?
	if #parts == 0 then
		return nil
	end

	self:ApplyFilter()

	const valid: { CFrame } = {}
	local firstGround: CFrame? = nil
	for _, sample in self:SampleCandidates(parts) do
		const resolved = self:Resolve(sample.point, sample.part)
		if resolved and resolved.hasGround then
			if firstGround == nil then
				firstGround = resolved.cframe
			end
			if resolved.valid then
				table.insert(valid, resolved.cframe)
			end
		end
	end

	local chosen: CFrame? = nil
	if #valid > 0 then
		self:PruneRecent()

		local pool: { CFrame } = {}
		for _, candidate in valid do
			local recent = false
			for _, entry in self.RecentSpawns do
				if (entry.pos - candidate.Position).Magnitude < MatchSettings.SpawnRecentRadius then
					recent = true
					break
				end
			end
			if not recent then
				table.insert(pool, candidate)
			end
		end
		if #pool == 0 then
			pool = valid
		end

		const enemies = self:GetEnemyPositions(player)
		if #enemies == 0 then
			chosen = pool[math.random(1, #pool)]
		else
			const scored: { { cframe: CFrame, distance: number } } = {}
			for _, candidate in pool do
				local nearest = math.huge
				for _, position in enemies do
					nearest = math.min(nearest, (position - candidate.Position).Magnitude)
				end
				table.insert(scored, { cframe = candidate, distance = nearest })
			end
			table.sort(scored, function(a: { cframe: CFrame, distance: number }, b: { cframe: CFrame, distance: number }): boolean
				return a.distance > b.distance
			end)
			const best = math.min(MatchSettings.SpawnEnemyBest, #scored)
			chosen = scored[math.random(1, best)].cframe
		end
	end

	if chosen == nil then
		chosen = firstGround
	end
	if chosen == nil then
		return self:RandomPointOn(parts[math.random(1, #parts)])
	end

	table.insert(self.RecentSpawns, { pos = chosen.Position, time = os.clock() })
	return chosen
end

function SpawnService:RandomPointOn(part: BasePart): CFrame
	const offsetX = (math.random() - 0.5) * part.Size.X
	const offsetZ = (math.random() - 0.5) * part.Size.Z
	const top = part.CFrame * CFrame.new(offsetX, part.Size.Y / 2, offsetZ)
	return top + MatchSettings.SpawnOffset
end

function SpawnService:GetTeamSpawnCFrame(teamName: string): CFrame?
	const part = self.Dependencies.EnvironmentService:GetTeamSpawn(teamName)
	return if part then self:RandomPointOn(part) else nil
end

function SpawnService:ReleaseSlot(player: Player)
	const slot = self.SlotOf[player]
	if slot == nil then
		return
	end

	self.SlotOf[player] = nil
	if self.Slots[slot] == player then
		self.Slots[slot] = nil
	end
end

function SpawnService:AssignSlot(player: Player): number
	const current = self.SlotOf[player]
	if current ~= nil then
		return current
	end

	local chosen: number? = nil
	const provider = self.SlotProvider
	if provider then
		const provided = provider(player)
		if provided ~= nil and provided >= 1 and provided <= MatchSettings.LobbySlotCount then
			const occupant = self.Slots[provided]
			if occupant == nil or occupant == player then
				chosen = provided
			end
		end
	end

	if chosen == nil then
		for index = 1, MatchSettings.LobbySlotCount do
			if self.Slots[index] == nil then
				chosen = index
				break
			end
		end
	end

	if chosen == nil then
		return math.random(1, MatchSettings.LobbySlotCount)
	end

	self.Slots[chosen] = player
	self.SlotOf[player] = chosen
	return chosen
end

function SpawnService:GetSlotCFrame(slot: number): CFrame?
	const part = self.Dependencies.EnvironmentService:GetLobbySlot(slot)
	return if part then part.CFrame + MatchSettings.SpawnOffset else nil
end

function SpawnService:MoveToSlot(player: Player, slot: number)
	if slot < 1 or slot > MatchSettings.LobbySlotCount then
		return
	end

	self:ReleaseSlot(player)
	const occupant = self.Slots[slot]
	if occupant and occupant ~= player then
		self.SlotOf[occupant] = nil
	end
	self.Slots[slot] = player
	self.SlotOf[player] = slot

	const destination = self:GetSlotCFrame(slot)
	if not destination then
		return
	end

	const character = player.Character
	if character and character.Parent then
		character:PivotTo(destination)
	elseif self.Destination[player] then
		self.Destination[player] = destination
	end
end

function SpawnService:ArrangeSlots(assignments: { [Player]: number })
	if not self.Dependencies.ServerRoleService:IsLobby() then
		return
	end

	const moves: { [Player]: number } = {}
	for player, slot in assignments do
		if self.SlotOf[player] ~= slot then
			moves[player] = slot
			self:ReleaseSlot(player)
		end
	end

	for player, slot in moves do
		if player:IsDescendantOf(Players) then
			self:MoveToSlot(player, slot)
		end
	end
end

function SpawnService:GetLobbyDestination(player: Player): CFrame?
	const slot = self:AssignSlot(player)
	const part = self.Dependencies.EnvironmentService:GetLobbySlot(slot)
	return if part then part.CFrame + MatchSettings.SpawnOffset else nil
end

function SpawnService:GetMatchDestination(player: Player): CFrame?
	const team = self.Dependencies.TeamService:GetTeam(player)
	if team then
		const teamPart = self.Dependencies.EnvironmentService:GetTeamSpawn(team)
		if teamPart then
			const teamSpawn = self:PickSpawn(player, { teamPart })
			if teamSpawn then
				return teamSpawn
			end
		end
	end

	return self:PickSpawn(player, self.Dependencies.EnvironmentService:GetFFASpawns())
end

function SpawnService:GetDestination(player: Player): CFrame?
	if self.Dependencies.ServerRoleService:IsLobby() then
		return self:GetLobbyDestination(player)
	end

	return self:GetMatchDestination(player)
end

function SpawnService:SpawnPlayer(player: Player)
	if not player:IsDescendantOf(Players) then
		return
	end

	if not self.Enabled then
		self.Pending[player] = true
		return
	end

	if self.Dependencies.ServerRoleService:IsRouter() then
		self.Pending[player] = nil
		return
	end

	self.Pending[player] = nil
	if self.Spawning[player] then
		return
	end
	self.Spawning[player] = true
	self.Epoch[player] = (self.Epoch[player] or 0) + 1

	self.Destination[player] = self:GetDestination(player)

	task.spawn(function()
		if player:IsDescendantOf(Players) then
			pcall(function()
				player:LoadCharacter()
			end)
		end
		self.Spawning[player] = nil
	end)
end

function SpawnService:Respawn(player: Player, delay: number?)
	const epoch = self.Epoch[player] or 0
	task.delay(delay or 0, function()
		if player:IsDescendantOf(Players) and (self.Epoch[player] or 0) == epoch then
			self:SpawnPlayer(player)
		end
	end)
end

function SpawnService:RespawnAll()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			const deadline = os.clock() + SPAWN_WAIT_TIMEOUT
			while self.Spawning[player] and os.clock() < deadline do
				task.wait()
			end

			if player:IsDescendantOf(Players) then
				self:Respawn(player, 0)
			end
		end)
	end
end

function SpawnService:Enable()
	self.Enabled = true

	const pending: { Player } = {}
	for player in self.Pending do
		table.insert(pending, player)
	end
	for _, player in pending do
		self:SpawnPlayer(player)
	end

	for _, player in Players:GetPlayers() do
		if player.Character == nil and not self.Spawning[player] then
			self:SpawnPlayer(player)
		end
	end
end

function SpawnService:Forget(player: Player)
	self:ReleaseSlot(player)
	self.Pending[player] = nil
	self.Spawning[player] = nil
	self.Epoch[player] = nil
	self.Destination[player] = nil
end

SpawnService:OnInit(function(self)
	self:Setup()

	Players.CharacterAutoLoads = false

	const playerService = self.Dependencies.PlayerService

	playerService.PlayerAdded:Connect(function(player)
		self:SpawnPlayer(player)
	end)

	playerService.PlayerRemoving:Connect(function(player)
		self:Forget(player)
	end)

	playerService.CharacterAdded:Connect(function(player, character)
		const destination = self.Destination[player]
		if destination then
			self.Destination[player] = nil
			character:PivotTo(destination)

			const root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				root.Anchored = false
			end

			const humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.PlatformStand = false
			end
		end
	end)
end)

SpawnService:OnStart(function(self)
	self.Dependencies.EnvironmentService:OnReady(function()
		self:Enable()
	end)
end)

return SpawnService
