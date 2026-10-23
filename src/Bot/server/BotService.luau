--!strict
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local BotNet = require(ReplicatedStorage.shared.Bot.Net)
local BotSettings = require(ReplicatedStorage.shared.Bot.BotSettings)
local GameModes = require(ReplicatedStorage.shared.Match.GameModes)
local GetBodyPart = require(ReplicatedStorage.shared.Hit.GetBodyPart)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local MatchSettings = require(ReplicatedStorage.shared.Match.MatchSettings)
local WeaponSounds = require(ReplicatedStorage.shared.Weapon.WeaponSounds)
local BotTypes = require(ServerScriptService.server.Bot.BotTypes)
local GunRules = require(ServerScriptService.server.Weapon.GunRules)
local Modux = require(ServerScriptService.server.Modux)

type Bot = BotTypes.Bot
type Fighter = BotTypes.Fighter
type ResolvedHit = { Target: Fighter, HitPart: number, Distance: number }

export type Waypoint = { Position: Vector3, Jump: boolean }

export type Brain = {
	Epoch: number,
	Waypoints: { Waypoint },
	Index: number,
	Goal: Vector3?,
	NextPath: number,
	Pathing: boolean,
	FallSpeed: number,
	Velocity: Vector3,
	StuckSince: number?,
	Escape: Vector3?,
	EscapeUntil: number,
	ProgressPos: Vector3,
	ProgressAt: number,
	Target: Fighter?,
	TargetVisible: boolean,
	LastSeen: number,
	LastSeenAt: Vector3?,
	ReadyAt: number,
	Strafe: number,
	NextStrafe: number,
	Rig: Model?,
	Reskinning: boolean,
	Mode: string,
	Advance: number,
	CoverUntil: number,
	NextCover: number,
	WeavePhase: number,
}

const MAX_BOTS = 32
const WANDER_SAMPLES = 8
const KILL_HEIGHT_MARGIN = 5
const HEAD_AIM_CHANCE = 0.25
const FACE_DISTANCE = 50
const RIG_WAIT = 0.2

const groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true

const sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

const shotParams = RaycastParams.new()
shotParams.FilterType = Enum.RaycastFilterType.Exclude

const BotService = Modux.Service("BotService", {
	Require = {
		"BotRegistryService",
		"EnvironmentService",
		"GameStateService",
		"HitService",
		"MatchStatsService",
		"NetService",
		"PlayerService",
		"ServerRoleService",
		"SnapshotService",
		"SpawnService",
		"TeamService",
	},
	Priority = 280,
})

function BotService:Setup()
	self.Active = false :: boolean
	self.Target = 0 :: number
	self.Brains = {} :: { [Bot]: Brain }
	self.Friends = {} :: { [Player]: { number } }
	self.FriendsLoading = 0 :: number
	self.Bounds = nil :: { CFrame: CFrame, Size: Vector3, FloorTop: number }?
	self.UsedAvatars = {} :: { [number]: Bot }
	self.UsedNames = {} :: { [string]: boolean }

	const rigs = Instance.new("Folder")
	rigs.Name = BotSettings.RigFolder
	rigs.Parent = ReplicatedStorage
	self.Rigs = rigs :: Folder
end

function BotService:ModeName(): string?
	const config = self.Dependencies.ServerRoleService:GetConfig()
	return if config then config.Mode else nil
end

function BotService:ShouldRun(): boolean
	const roleService = self.Dependencies.ServerRoleService
	if not roleService.IsReady or not roleService:IsMatch() then
		return false
	end

	const config = roleService:GetConfig()
	if not config or config.Private or BotSettings.ExcludedModes[config.Mode] then
		return false
	end

	return GameModes.Modes[config.Mode] ~= nil
end

function BotService:Activate()
	if not self:ShouldRun() then
		return
	end

	const mode = self:ModeName() :: string
	self.Active = true
	self.Target = math.min(GameModes.GetMaxPlayers(mode), MAX_BOTS)
	self:Reconcile()
end

function BotService:Desired(): number
	const humans = #Players:GetPlayers()
	if not self.Active or humans == 0 then
		return 0
	end
	return math.max(self.Target - humans, 0)
end

function BotService:Reconcile()
	const registry = self.Dependencies.BotRegistryService
	const desired = self:Desired()

	while registry:Count() > desired do
		const victim = self:PickReplaced(nil)
		if not victim then
			break
		end
		self:RemoveBot(victim)
	end

	while registry:Count() < desired do
		self:AddBot()
	end
end

function BotService:PickReplaced(newcomer: Player?): Bot?
	const registry = self.Dependencies.BotRegistryService
	const teamService = self.Dependencies.TeamService
	const bots = registry:All()
	if #bots == 0 then
		return nil
	end

	local pool = bots
	if teamService:IsTeamMode() then
		local heaviest: string? = nil
		local heaviestCount = -1
		const preferred = if newcomer then teamService:GetTeam(newcomer) else nil
		for _, teamName in MatchSettings.TeamNames do
			local botsOnTeam = 0
			for _, bot in bots do
				if teamService:GetTeam(bot) == teamName then
					botsOnTeam += 1
				end
			end
			if botsOnTeam == 0 then
				continue
			end
			const count = teamService:Count(teamName)
			if count > heaviestCount or (count == heaviestCount and teamName == preferred) then
				heaviest = teamName
				heaviestCount = count
			end
		end

		if heaviest then
			const filtered: { Bot } = {}
			for _, bot in bots do
				if teamService:GetTeam(bot) == heaviest then
					table.insert(filtered, bot)
				end
			end
			pool = filtered
		end
	end

	const stats = self.Dependencies.MatchStatsService
	table.sort(pool, function(first: Bot, second: Bot): boolean
		const a = stats:Get(first)
		const b = stats:Get(second)
		const scoreA = if a then a.Score else 0
		const scoreB = if b then b.Score else 0
		if first.Alive ~= second.Alive then
			return not first.Alive
		end
		return scoreA < scoreB
	end)
	return pool[1]
end

function BotService:PickName(): string
	const taken: { [string]: boolean } = table.clone(self.UsedNames)
	for _, player in Players:GetPlayers() do
		taken[player.Name] = true
		taken[player.DisplayName] = true
	end

	const free: { string } = {}
	for _, name in BotSettings.Names do
		if not taken[name] then
			table.insert(free, name)
		end
	end

	if #free == 0 then
		return `{BotSettings.Names[math.random(1, #BotSettings.Names)]}{math.random(10, 99)}`
	end
	return free[math.random(1, #free)]
end

function BotService:LoadFriends(player: Player)
	if self.Friends[player] ~= nil then
		return
	end
	self.Friends[player] = {}
	self.FriendsLoading += 1

	task.spawn(function()
		const ids: { number } = {}
		const ok, pages = pcall(function()
			return Players:GetFriendsAsync(player.UserId)
		end)
		if not ok or not pages then
			self.FriendsLoading -= 1
			warn(`[BotService] nao foi possivel ler amigos de {player.Name} ({player.UserId}): {pages}`)
			return
		end

		while #ids < BotSettings.FriendScanLimit do
			for _, entry in pages:GetCurrentPage() do
				const id = (entry :: any).Id
				if typeof(id) == "number" then
					table.insert(ids, id)
				end
			end
			if pages.IsFinished then
				break
			end
			const advanced = pcall(function()
				pages:AdvanceToNextPageAsync()
			end)
			if not advanced then
				break
			end
		end

		self.FriendsLoading -= 1
		if self.Friends[player] ~= nil then
			self.Friends[player] = ids
			self:Reskin()
		end
	end)
end

function BotService:WaitFriends()
	const deadline = os.clock() + BotSettings.FriendWait
	while self.FriendsLoading > 0 and os.clock() < deadline do
		task.wait(RIG_WAIT)
	end
end

function BotService:ApplyRig(bot: Bot, brain: Brain, avatarId: number, rig: Model?): boolean
	if self.Dependencies.BotRegistryService:FromID(bot.GameID) ~= bot or self.Brains[bot] ~= brain then
		if rig then
			rig:Destroy()
		end
		if self.UsedAvatars[avatarId] == bot then
			self.UsedAvatars[avatarId] = nil
		end
		return false
	end

	if self.UsedAvatars[bot.AvatarId] == bot and bot.AvatarId ~= avatarId then
		self.UsedAvatars[bot.AvatarId] = nil
	end
	bot.AvatarId = avatarId
	if rig then
		if brain.Rig then
			brain.Rig:Destroy()
		end
		brain.Rig = rig
		rig.Parent = self.Rigs
	end
	self:PublishMember(bot)
	return true
end

function BotService:Reskin()
	for bot, brain in self.Brains do
		if bot.AvatarId > 0 or brain.Reskinning then
			continue
		end
		const avatarId = self:PickAvatar(bot)
		if avatarId == 0 then
			return
		end
		brain.Reskinning = true
		task.spawn(function()
			const rig = self:BuildRig(bot, avatarId)
			brain.Reskinning = false
			self:ApplyRig(bot, brain, avatarId, rig)
		end)
	end
end

function BotService:PickAvatar(bot: Bot): number
	const inServer: { [number]: boolean } = {}
	for _, player in Players:GetPlayers() do
		inServer[player.UserId] = true
	end

	const candidates: { number } = {}
	for _, ids in self.Friends do
		for _, id in ids do
			if not inServer[id] and self.UsedAvatars[id] == nil then
				table.insert(candidates, id)
			end
		end
	end

	if #candidates == 0 then
		return 0
	end

	const chosen = candidates[math.random(1, #candidates)]
	self.UsedAvatars[chosen] = bot
	return chosen
end

local function fallbackDescription(): HumanoidDescription
	const description = Instance.new("HumanoidDescription")
	const skin = Color3.fromHSV(math.random(5, 12) / 100, math.random(20, 60) / 100, math.random(45, 95) / 100)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = Color3.fromHSV(math.random(), 0.6, 0.8)
	description.LeftLegColor = Color3.fromHSV(math.random(), 0.4, 0.5)
	description.RightLegColor = description.LeftLegColor
	return description
end

function BotService:BuildRig(bot: Bot, avatarId: number): Model?
	local description: HumanoidDescription? = nil
	if avatarId > 0 then
		for _ = 1, BotSettings.AvatarAttempts do
			const ok, result = pcall(function()
				return Players:GetHumanoidDescriptionFromUserId(avatarId)
			end)
			if ok and result then
				description = result
				break
			end
			task.wait(RIG_WAIT)
		end
	end

	const ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description or fallbackDescription(), Enum.HumanoidRigType.R6)
	end)
	if not ok or not rig then
		warn(`[BotService] falha ao montar rig do bot {bot.DisplayName}: {rig}`)
		return nil
	end

	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ForceField") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.Massless = true
			descendant.Anchored = false
			descendant.CanQuery = descendant:FindFirstAncestorOfClass("Accessory") == nil
		end
	end

	const humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
	end

	const root = rig:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
		root.Transparency = 1
		rig.PrimaryPart = root
	end

	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const template = if assets then assets:FindFirstChild("PlayerBillboard") else nil
	if template and template:IsA("BillboardGui") and rig.PrimaryPart then
		const billboard = template:Clone()
		const label = billboard:FindFirstChild("TextLabel")
		if label and label:IsA("TextLabel") then
			label.Text = bot.DisplayName
		end
		billboard.Parent = rig.PrimaryPart
	end

	rig.Name = `{bot.UserId}_{avatarId}`
	rig:SetAttribute(BotSettings.GameIDAttribute, bot.GameID)
	return rig
end

function BotService:TeamName(bot: Bot): BotNet.Team
	const team = self.Dependencies.TeamService:GetTeam(bot)
	return if team == "Red" or team == "Blue" then team else "None"
end

function BotService:PublishMember(bot: Bot)
	if not self.Dependencies.NetService:IsRunning() then
		return
	end

	const roster = self.Libs.Net.Bot.Roster
	const record = {
		DisplayName = bot.DisplayName,
		UserId = bot.UserId,
		AvatarId = bot.AvatarId,
		Team = self:TeamName(bot),
	}
	if roster:get(bot.GameID) then
		roster:update(bot.GameID, record)
	else
		roster:add(bot.GameID, record)
	end
end

function BotService:AddBot()
	const registry = self.Dependencies.BotRegistryService
	const name = self:PickName()
	self.UsedNames[name] = true

	const bot = registry:Create(name, 0)
	const brain: Brain = {
		Epoch = 0,
		Waypoints = {},
		Index = 1,
		Goal = nil,
		NextPath = 0,
		Pathing = false,
		FallSpeed = 0,
		Velocity = Vector3.zero,
		StuckSince = nil,
		Escape = nil,
		EscapeUntil = 0,
		ProgressPos = Vector3.zero,
		ProgressAt = 0,
		Target = nil,
		TargetVisible = false,
		LastSeen = 0,
		LastSeenAt = nil,
		ReadyAt = 0,
		Strafe = 0,
		NextStrafe = 0,
		Rig = nil,
		Reskinning = false,
		Mode = "Wander",
		Advance = 0,
		CoverUntil = 0,
		NextCover = 0,
		WeavePhase = math.random() * math.pi * 2,
	}
	self.Brains[bot] = brain
	self:PublishMember(bot)

	task.spawn(function()
		self:WaitFriends()
		const avatarId = self:PickAvatar(bot)
		brain.Reskinning = true
		const rig = self:BuildRig(bot, avatarId)
		brain.Reskinning = false
		if self:ApplyRig(bot, brain, avatarId, rig) then
			self:Spawn(bot)
		end
	end)
end

function BotService:RemoveBot(bot: Bot)
	const brain = self.Brains[bot]
	if brain and brain.Rig then
		brain.Rig:Destroy()
	end
	self.Brains[bot] = nil
	self.UsedNames[bot.DisplayName] = nil
	if self.UsedAvatars[bot.AvatarId] == bot then
		self.UsedAvatars[bot.AvatarId] = nil
	end

	self.Dependencies.SnapshotService:ClearHistory(bot.GameID)
	if self.Dependencies.NetService:IsRunning() and self.Libs.Net.Bot.Roster:get(bot.GameID) then
		self.Libs.Net.Bot.Roster:remove(bot.GameID)
	end
	self.Dependencies.BotRegistryService:Remove(bot)
end

function BotService:GunPool(): { string }
	const pool: { string } = {}
	for name, data in GetGun.All do
		if data.FireMode == "Hitscan" and not data.Disabled and data.Damage > 1 then
			table.insert(pool, name)
		end
	end
	table.sort(pool)
	return pool
end

function BotService:Spawn(bot: Bot)
	const brain = self.Brains[bot]
	if not brain or self.Dependencies.BotRegistryService:FromID(bot.GameID) ~= bot then
		return
	end

	const spawnService = self.Dependencies.SpawnService
	if not spawnService.Enabled then
		task.delay(1, function()
			self:Spawn(bot)
		end)
		return
	end

	const destination = spawnService:GetMatchDestination(bot)
	if not destination then
		task.delay(1, function()
			self:Spawn(bot)
		end)
		return
	end

	const position = destination.Position + Vector3.new(0, BotSettings.RootHeight - MatchSettings.SpawnFootOffset, 0)
	self.Dependencies.SnapshotService:ClearHistory(bot.GameID)
	self.Dependencies.BotRegistryService:Revive(bot, position, position + destination.LookVector * FACE_DISTANCE)

	const pool = self:GunPool()
	bot.GunName = if #pool > 0 then pool[math.random(1, #pool)] else ""
	bot.LastShot = 0

	brain.Epoch += 1
	brain.Waypoints = {}
	brain.Index = 1
	brain.Goal = nil
	brain.NextPath = 0
	brain.FallSpeed = 0
	brain.Velocity = Vector3.zero
	brain.StuckSince = nil
	brain.Escape = nil
	brain.ProgressPos = position
	brain.ProgressAt = os.clock()
	brain.Target = nil
	brain.TargetVisible = false
	brain.LastSeenAt = nil
	brain.Pathing = false
	brain.Mode = "Wander"
	brain.Advance = 0
	brain.Strafe = 0
	brain.CoverUntil = 0

	const point = self:WanderPoint(position)
	if point then
		self:RequestPath(bot, brain, point, os.clock())
	end
end

function BotService:ScheduleRespawn(bot: Bot)
	const brain = self.Brains[bot]
	if not brain then
		return
	end

	brain.Epoch += 1
	const epoch = brain.Epoch
	brain.Target = nil
	brain.Waypoints = {}
	task.delay(MatchSettings.RespawnDelay, function()
		const current = self.Brains[bot]
		if current and current.Epoch == epoch and not bot.Alive then
			self:Spawn(bot)
		end
	end)
end

function BotService:RespawnAll()
	for _, bot in self.Dependencies.BotRegistryService:All() do
		if self.Brains[bot] then
			self:Spawn(bot)
		end
	end
end

function BotService:CharacterFilter(): { Instance }
	const filter: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	return filter
end

function BotService:Eye(bot: Bot): Vector3
	return bot.Position + Vector3.new(0, BotSettings.EyeHeight, 0)
end

function BotService:CanSee(from: Vector3, to: Vector3, filter: { Instance }): boolean
	sightParams.FilterDescendantsInstances = filter
	return workspace:Raycast(from, to - from, sightParams) == nil
end

function BotService:Acquire(bot: Bot, brain: Brain, filter: { Instance }, now: number)
	const teamService = self.Dependencies.TeamService
	const hitService = self.Dependencies.HitService
	const eye = self:Eye(bot)

	local best: Fighter? = nil
	local bestPosition: Vector3? = nil
	local bestDistance = BotSettings.SightRange
	for _, candidate in hitService:Candidates(bot) do
		if teamService:SameTeam(bot, candidate.Fighter) then
			continue
		end

		const distance = (candidate.Root - eye).Magnitude
		if distance > bestDistance then
			continue
		end

		const aim = candidate.Root + Vector3.new(0, 1, 0)
		if not self:CanSee(eye, aim, filter) then
			continue
		end

		best = candidate.Fighter
		bestPosition = candidate.Root
		bestDistance = distance
	end

	if best and bestPosition then
		if brain.Target ~= best or not brain.TargetVisible then
			brain.ReadyAt = now + BotSettings.ReactionMin + math.random() * (BotSettings.ReactionMax - BotSettings.ReactionMin)
		end
		brain.Target = best
		brain.TargetVisible = true
		brain.LastSeen = now
		brain.LastSeenAt = bestPosition
		return
	end

	brain.TargetVisible = false
	if brain.Target and now - brain.LastSeen > BotSettings.MemorySeconds then
		brain.Target = nil
		brain.LastSeenAt = nil
	end
end

function BotService:WanderParts(): { BasePart }
	const root = self.Dependencies.EnvironmentService:GetRoot()
	const parts: { BasePart } = {}
	for _, tag in { "WeaponSpawn", "Farmland" } do
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsA("BasePart") and (not root or instance:IsDescendantOf(root)) then
				table.insert(parts, instance)
			end
		end
	end
	for _, part in self.Dependencies.SpawnService:GetSpawnParts() do
		table.insert(parts, part)
	end
	return parts
end

function BotService:MapBounds(): (CFrame?, Vector3?)
	if self.Bounds then
		return self.Bounds.CFrame, self.Bounds.Size
	end

	const root = self.Dependencies.EnvironmentService:GetRoot()
	if not root then
		return nil, nil
	end

	local center: CFrame
	local size: Vector3
	if root:IsA("Model") then
		center, size = root:GetBoundingBox()
	else
		local low = Vector3.one * math.huge
		local high = -Vector3.one * math.huge
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("BasePart") then
				const half = descendant.Size / 2
				low = low:Min(descendant.Position - half)
				high = high:Max(descendant.Position + half)
			end
		end
		if low.X == math.huge then
			return nil, nil
		end
		center = CFrame.new((low + high) / 2)
		size = high - low
	end

	local floorTop = -math.huge
	for _, part in self.Dependencies.SpawnService:GetSpawnParts() do
		floorTop = math.max(floorTop, part.Position.Y + part.Size.Y / 2)
	end
	self.Bounds = { CFrame = center, Size = size, FloorTop = floorTop }
	return center, size
end

function BotService:MapPoint(): Vector3?
	const center, size = self:MapBounds()
	const bounds = self.Bounds
	if not center or not size or not bounds then
		return nil
	end

	const margin = BotSettings.EdgeMargin
	const halfX = math.max(size.X / 2 - margin, 1)
	const halfZ = math.max(size.Z / 2 - margin, 1)
	local x = (math.random() * 2 - 1) * halfX
	local z = (math.random() * 2 - 1) * halfZ
	if math.random() < BotSettings.EdgeBias then
		const band = BotSettings.EdgeBand
		const side = math.random(1, 4)
		const inward = 1 - math.random() * band
		if side == 1 then
			x = halfX * inward
		elseif side == 2 then
			x = -halfX * inward
		elseif side == 3 then
			z = halfZ * inward
		else
			z = -halfZ * inward
		end
	end

	const top = center.Position.Y + size.Y / 2 + 5
	const origin = center:PointToWorldSpace(Vector3.new(x, 0, z))
	groundParams.FilterDescendantsInstances = self:CharacterFilter()
	const hit = workspace:Raycast(Vector3.new(origin.X, top, origin.Z), Vector3.new(0, -(size.Y + 20), 0), groundParams)
	if not hit or hit.Normal.Y < 0.7 then
		return nil
	end
	if bounds.FloorTop > -math.huge and hit.Position.Y > bounds.FloorTop + BotSettings.MaxWanderRise then
		return nil
	end
	return hit.Position
end

function BotService:WanderPoint(from: Vector3): Vector3?
	if math.random() < BotSettings.MapPointChance then
		for _ = 1, WANDER_SAMPLES do
			const point = self:MapPoint()
			if point and (point - from).Magnitude >= BotSettings.WanderMinDistance then
				return point
			end
		end
	end

	const parts = self:WanderParts()
	if #parts == 0 then
		return self:MapPoint()
	end

	local fallback: Vector3? = nil
	for _ = 1, WANDER_SAMPLES do
		const part = parts[math.random(1, #parts)]
		const offset = Vector3.new((math.random() - 0.5) * part.Size.X, part.Size.Y / 2, (math.random() - 0.5) * part.Size.Z)
		const point = part.CFrame:PointToWorldSpace(offset)
		if point.Y <= workspace.FallenPartsDestroyHeight then
			continue
		end
		if (point - from).Magnitude >= BotSettings.WanderMinDistance then
			return point
		end
		fallback = fallback or point
	end
	return fallback
end

function BotService:Feet(position: Vector3): Vector3
	return position - Vector3.new(0, BotSettings.RootHeight, 0)
end

function BotService:Clear(from: Vector3, to: Vector3, filter: { Instance }): boolean
	groundParams.FilterDescendantsInstances = filter
	const lift = Vector3.new(0, BotSettings.StepHeight + 0.25 - BotSettings.RootHeight, 0)
	const start = from + lift
	const finish = Vector3.new(to.X, from.Y, to.Z) + lift
	const offset = finish - start
	if offset.Magnitude < 0.1 then
		return true
	end

	const side = offset.Unit:Cross(Vector3.yAxis) * BotSettings.ClearanceRadius
	for _, shift in { Vector3.zero, side, -side } do
		if workspace:Raycast(start + shift, offset, groundParams) then
			return false
		end
	end
	return true
end

function BotService:RequestPath(bot: Bot, brain: Brain, goal: Vector3, now: number, force: boolean?)
	if brain.Pathing or (now < brain.NextPath and not force) then
		return
	end
	brain.Pathing = true
	brain.NextPath = now + BotSettings.RepathInterval
	brain.Goal = goal

	const epoch = brain.Epoch
	const start = self:Feet(bot.Position) + Vector3.new(0, 0.5, 0)
	task.spawn(function()
		const path = PathfindingService:CreatePath({
			AgentRadius = BotSettings.AgentRadius,
			AgentHeight = BotSettings.AgentHeight,
			AgentCanJump = true,
			AgentCanClimb = false,
			WaypointSpacing = BotSettings.WaypointSpacing,
		})
		const ok = pcall(function()
			path:ComputeAsync(start, goal)
		end)
		brain.Pathing = false
		if brain.Epoch ~= epoch or self.Brains[bot] ~= brain then
			return
		end

		if not ok or path.Status ~= Enum.PathStatus.Success then
			brain.Goal = nil
			brain.NextPath = os.clock() + BotSettings.PathRetryDelay
			return
		end

		const waypoints: { Waypoint } = {}
		for _, waypoint in path:GetWaypoints() do
			table.insert(waypoints, {
				Position = waypoint.Position,
				Jump = waypoint.Action == Enum.PathWaypointAction.Jump,
			})
		end
		brain.Waypoints = waypoints
		brain.Index = math.min(2, #waypoints)
	end)
end

function BotService:PlanWander(bot: Bot, brain: Brain, now: number)
	if brain.Index > #brain.Waypoints and not brain.Pathing then
		const point = self:WanderPoint(bot.Position)
		if point then
			self:RequestPath(bot, brain, point, now)
		end
	end
end

function BotService:Think(bot: Bot, brain: Brain, filter: { Instance }, now: number)
	self:Acquire(bot, brain, filter, now)

	const target = brain.Target
	const gunData = GetGun.ByName(bot.GunName)
	const range = if gunData then gunData.Range * BotSettings.EngageRange else 60

	if target and brain.LastSeenAt then
		const distance = (brain.LastSeenAt - bot.Position).Magnitude

		if brain.Mode == "Cover" then
			if now < brain.CoverUntil then
				self:Juke(brain, now)
				return
			end
			brain.Mode = "Fight"
		end

		if brain.TargetVisible and distance <= range then
			if now >= brain.NextCover and not brain.Pathing then
				const hurt = bot.Health < BotSettings.CoverHealth
				if hurt or math.random() < BotSettings.CoverChance then
					brain.NextCover = now + BotSettings.CoverCooldown
					const cover = self:CoverPoint(bot, brain.LastSeenAt, filter)
					if cover then
						brain.Mode = "Cover"
						brain.CoverUntil = now + BotSettings.CoverSeconds
						brain.Waypoints = {}
						self:RequestPath(bot, brain, cover, now, true)
						return
					end
				end
			end

			brain.Mode = "Fight"
			brain.Waypoints = {}
			brain.Goal = nil
			self:Juke(brain, now)
			const ideal = range * BotSettings.IdealRange
			if distance > ideal * 1.3 then
				brain.Advance = 1
			elseif distance < math.max(ideal * 0.6, BotSettings.MinFightDistance) then
				brain.Advance = -1
			elseif now >= brain.NextStrafe - 0.05 then
				brain.Advance = math.random(-1, 1) * 0.5
			end
			return
		end

		brain.Mode = "Chase"
		brain.Strafe = 0
		self:RequestPath(bot, brain, self:Feet(brain.LastSeenAt), now)
		return
	end

	brain.Mode = "Wander"
	brain.Strafe = 0
	brain.Advance = 0
	self:PlanWander(bot, brain, now)
end

function BotService:Juke(brain: Brain, now: number)
	if brain.Strafe == 0 then
		brain.Strafe = if math.random() < 0.5 then -1 else 1
	end
	if now >= brain.NextStrafe then
		brain.NextStrafe = now + BotSettings.StrafeMin + math.random() * (BotSettings.StrafeMax - BotSettings.StrafeMin)
		if math.random() < BotSettings.StrafeFlipChance then
			brain.Strafe = -brain.Strafe
		end
	end
end

function BotService:CoverPoint(bot: Bot, threat: Vector3, filter: { Instance }): Vector3?
	const eye = threat + Vector3.new(0, BotSettings.EyeHeight, 0)
	local best: Vector3? = nil
	local bestDistance = math.huge
	const base = math.random() * math.pi * 2
	for index = 1, BotSettings.CoverDirections do
		const angle = base + (index - 1) * (math.pi * 2 / BotSettings.CoverDirections)
		const direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		for _, distance in BotSettings.CoverDistances do
			if distance >= bestDistance then
				continue
			end
			const candidate = bot.Position + direction * distance
			const floor = self:Ground(candidate, filter, BotSettings.JumpHeight)
			if not floor or math.abs(floor - bot.Position.Y) > BotSettings.StepHeight * 2 then
				continue
			end
			const standing = Vector3.new(candidate.X, floor, candidate.Z)
			sightParams.FilterDescendantsInstances = filter
			if not workspace:Raycast(eye, standing - eye, sightParams) then
				continue
			end
			best = self:Feet(standing)
			bestDistance = distance
		end
	end
	return best
end

function BotService:Ground(position: Vector3, filter: { Instance }, height: number?): number?
	groundParams.FilterDescendantsInstances = filter
	const rise = height or BotSettings.StepHeight
	const origin = self:Feet(position) + Vector3.new(0, rise + 0.5, 0)
	const hit = workspace:Raycast(origin, Vector3.new(0, -(rise + 10), 0), groundParams)
	return if hit then hit.Position.Y + BotSettings.RootHeight else nil
end

function BotService:Wall(position: Vector3, step: Vector3, filter: { Instance }): RaycastResult?
	if step.Magnitude < 0.001 then
		return nil
	end
	groundParams.FilterDescendantsInstances = filter
	const origin = self:Feet(position) + Vector3.new(0, BotSettings.StepHeight + 0.25, 0)
	return workspace:Raycast(origin, step.Unit * (step.Magnitude + BotSettings.ClearanceRadius), groundParams)
end

function BotService:Separation(bot: Bot): Vector3
	local push = Vector3.zero
	for other in self.Brains do
		if other == bot or not other.Alive then
			continue
		end
		const offset = Vector3.new(bot.Position.X - other.Position.X, 0, bot.Position.Z - other.Position.Z)
		const distance = offset.Magnitude
		if distance < BotSettings.SeparationRadius then
			const away = if distance > 0.05 then offset.Unit else Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
			push += away * (1 - distance / BotSettings.SeparationRadius)
		end
	end
	return push
end

function BotService:Steer(bot: Bot, brain: Brain, filter: { Instance }, now: number): (Vector3, number, boolean)
	if brain.Escape and now < brain.EscapeUntil then
		return brain.Escape, BotSettings.WalkSpeed, false
	end
	brain.Escape = nil

	local waypoint = brain.Waypoints[brain.Index]
	while waypoint do
		const flat = Vector3.new(waypoint.Position.X - bot.Position.X, 0, waypoint.Position.Z - bot.Position.Z)
		if flat.Magnitude > BotSettings.ArriveRadius then
			break
		end
		brain.Index += 1
		waypoint = brain.Waypoints[brain.Index]
	end

	while waypoint and not waypoint.Jump do
		const following = brain.Waypoints[brain.Index + 1]
		if not following or following.Jump or not self:Clear(bot.Position, following.Position, filter) then
			break
		end
		brain.Index += 1
		waypoint = following
	end

	local goal: Vector3? = if waypoint then waypoint.Position else nil
	if not goal and brain.Pathing and brain.Goal and not brain.Target and self:Clear(bot.Position, brain.Goal, filter) then
		goal = brain.Goal
	end

	const speed = if brain.Target then BotSettings.ChaseSpeed else BotSettings.WalkSpeed
	if goal then
		const flat = Vector3.new(goal.X - bot.Position.X, 0, goal.Z - bot.Position.Z)
		if flat.Magnitude > 0.1 then
			const jump = waypoint ~= nil and waypoint.Jump and flat.Magnitude <= BotSettings.JumpTriggerDistance
			local direction = flat.Unit
			if brain.Mode == "Wander" and flat.Magnitude > BotSettings.WeaveMinDistance then
				const angle = math.sin(now * BotSettings.WeaveFrequency + brain.WeavePhase) * math.rad(BotSettings.WeaveAngle)
				const weaved = CFrame.Angles(0, angle, 0):VectorToWorldSpace(direction)
				if self:Clear(bot.Position, bot.Position + weaved * BotSettings.ClearanceRadius * 3, filter) then
					direction = weaved
				end
			end
			return direction, speed, jump
		end
	end

	if brain.LastSeenAt and (brain.Mode == "Fight" or brain.Mode == "Cover") then
		const toward = Vector3.new(brain.LastSeenAt.X - bot.Position.X, 0, brain.LastSeenAt.Z - bot.Position.Z)
		if toward.Magnitude > 0.1 then
			const forward = toward.Unit
			const lateral = forward:Cross(Vector3.yAxis) * (if brain.Strafe ~= 0 then brain.Strafe else 1)
			const advance = if brain.Mode == "Cover" then 0 else brain.Advance
			const combined = lateral + forward * advance * BotSettings.AdvanceWeight
			const pace = if brain.Mode == "Cover" then BotSettings.CoverShuffle else 1
			if combined.Magnitude > 0.05 then
				return combined.Unit * pace, BotSettings.FightSpeed, false
			end
		end
	end

	if brain.Mode == "Wander" and brain.Velocity.Magnitude > 1 then
		const heading = Vector3.new(brain.Velocity.X, 0, brain.Velocity.Z).Unit
		if self:Clear(bot.Position, bot.Position + heading * BotSettings.CoastDistance, filter) then
			return heading, BotSettings.WalkSpeed, false
		end
	end
	return Vector3.zero, speed, false
end

function BotService:Unstick(brain: Brain, now: number)
	brain.Waypoints = {}
	brain.Index = 1
	brain.Goal = nil
	brain.NextPath = 0
	brain.Strafe = 0
	brain.StuckSince = nil
	const angle = math.random() * math.pi * 2
	brain.Escape = Vector3.new(math.cos(angle), 0, math.sin(angle))
	brain.EscapeUntil = now + BotSettings.EscapeSeconds
	brain.ProgressAt = now
end

function BotService:Move(bot: Bot, brain: Brain, filter: { Instance }, dt: number, canMove: boolean, now: number)
	local desired = Vector3.zero
	local speed = BotSettings.WalkSpeed
	local wantsJump = false

	if canMove then
		desired, speed, wantsJump = self:Steer(bot, brain, filter, now)
		const push = self:Separation(bot)
		if push.Magnitude > 0 then
			const blended = desired + push * BotSettings.SeparationWeight
			desired = if blended.Magnitude > 0.05 then blended.Unit * math.max(desired.Magnitude, math.min(push.Magnitude, 1)) else Vector3.zero
		end
	end

	const blend = math.min(BotSettings.Acceleration * dt, 1)
	brain.Velocity = brain.Velocity:Lerp(desired * speed, blend)
	if brain.Velocity.Magnitude < 0.05 then
		brain.Velocity = Vector3.zero
	end

	local position = bot.Position
	const floorHere = self:Ground(position, filter)
	const grounded = floorHere ~= nil and brain.FallSpeed >= 0 and position.Y - floorHere <= 0.6

	local step = brain.Velocity * dt
	local blocked = false
	const wall = self:Wall(position, step, filter)
	if wall then
		const normal = Vector3.new(wall.Normal.X, 0, wall.Normal.Z)
		const slide = if normal.Magnitude > 0.01 then step - normal.Unit * step:Dot(normal.Unit) else Vector3.zero
		if slide.Magnitude > 0.01 and not self:Wall(position, slide, filter) then
			step = slide
			brain.Velocity = slide / dt
		else
			blocked = true
		end
	end

	if not blocked and step.Magnitude > 0 then
		const rise = self:Ground(position + step, filter, BotSettings.JumpHeight)
		if rise and rise - position.Y > BotSettings.StepHeight then
			blocked = true
		end
	end

	if blocked then
		const ahead = if step.Magnitude > 0.001 then step.Unit else desired
		const top = if ahead.Magnitude > 0.001
			then self:Ground(position + ahead * (BotSettings.ClearanceRadius + 1), filter, BotSettings.JumpHeight)
			else nil
		if grounded and top and top - position.Y <= BotSettings.JumpHeight then
			wantsJump = true
		else
			step = Vector3.zero
			brain.Velocity = Vector3.zero
			brain.StuckSince = brain.StuckSince or now
		end
	end

	if wantsJump and grounded then
		brain.FallSpeed = -BotSettings.JumpPower
	end

	position += step
	const floor = self:Ground(position, filter)
	if brain.FallSpeed >= 0 and floor and position.Y - floor <= brain.FallSpeed * dt + 0.6 then
		position = Vector3.new(position.X, floor, position.Z)
		brain.FallSpeed = 0
	else
		brain.FallSpeed += BotSettings.Gravity * dt
		position -= Vector3.new(0, brain.FallSpeed * dt, 0)
		if brain.FallSpeed >= 0 and floor and position.Y < floor then
			position = Vector3.new(position.X, floor, position.Z)
			brain.FallSpeed = 0
		end
	end

	if step.Magnitude > 0 then
		brain.StuckSince = nil
	end

	if desired.Magnitude > 0 then
		if (position - brain.ProgressPos).Magnitude >= BotSettings.ProgressDistance then
			brain.ProgressPos = position
			brain.ProgressAt = now
		elseif now - brain.ProgressAt > BotSettings.ProgressSeconds then
			self:Unstick(brain, now)
		end
	else
		brain.ProgressPos = position
		brain.ProgressAt = now
	end

	if brain.StuckSince and now - brain.StuckSince > BotSettings.StuckSeconds then
		self:Unstick(brain, now)
	end

	bot.Position = position
	const moving = step.Magnitude > 0.001
	const velocity = brain.Velocity
	const pace = math.min(velocity.Magnitude / BotSettings.ChaseSpeed, 1)
	bot.MoveDir = if moving and velocity.Magnitude > 0.001 then Vector2.new(velocity.X, velocity.Z).Unit * pace else Vector2.zero
	bot.State = if brain.FallSpeed < 0 or brain.FallSpeed > BotSettings.FallStateSpeed
		then "Jumping"
		elseif moving then "Running"
		else "Walking"

	if brain.Target and brain.LastSeenAt then
		bot.LookAt = brain.LastSeenAt + Vector3.new(0, 1, 0)
	elseif moving and velocity.Magnitude > 0.5 then
		bot.LookAt = position + velocity.Unit * FACE_DISTANCE + Vector3.new(0, BotSettings.EyeHeight, 0)
	end

	if position.Y < workspace.FallenPartsDestroyHeight + KILL_HEIGHT_MARGIN then
		self.Dependencies.BotRegistryService:Damage(bot, bot.Health + bot.Armor)
	end
end

function BotService:AimPoint(target: Fighter): Vector3?
	const bot = BotTypes.AsBot(target)
	if bot then
		if not bot.Alive then
			return nil
		end
		return if math.random() < HEAD_AIM_CHANCE then bot.Position + Vector3.new(0, BotSettings.EyeHeight, 0) else bot.Position
	end

	const character = BotTypes.Character(target)
	if not character then
		return nil
	end
	const partName = if math.random() < HEAD_AIM_CHANCE then "Head" else "Torso"
	const part = character:FindFirstChild(partName) or character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part.Position else nil
end

function BotService:Trace(bot: Bot, origin: Vector3, direction: Vector3, range: number): ResolvedHit?
	const registry = self.Dependencies.BotRegistryService
	shotParams.FilterDescendantsInstances = {}
	const result = workspace:Raycast(origin, direction * range, shotParams)
	const worldDistance = if result then result.Distance else range

	const other, botDistance, botPart = registry:RayHit(origin, direction, worldDistance, bot)
	if other then
		return { Target = other, HitPart = botPart, Distance = botDistance }
	end

	if not result then
		return nil
	end

	const model = result.Instance:FindFirstAncestorOfClass("Model")
	const player = if model then Players:GetPlayerFromCharacter(model) else nil
	if not player then
		return nil
	end
	return { Target = player, HitPart = GetBodyPart.Get(result.Instance.Name), Distance = result.Distance }
end

function BotService:Shoot(bot: Bot, brain: Brain, now: number)
	const target = brain.Target
	const gunData = GetGun.ByName(bot.GunName)
	if not target or not brain.TargetVisible or not gunData or now < brain.ReadyAt then
		return
	end
	if now - bot.LastShot < gunData.FireRate then
		return
	end

	const hitService = self.Dependencies.HitService
	if not hitService:IsAlive(target) then
		brain.Target = nil
		return
	end

	const aim = self:AimPoint(target)
	if not aim then
		return
	end

	const eye = self:Eye(bot)
	const offset = aim - eye
	if offset.Magnitude > gunData.Range or offset.Magnitude < 0.1 then
		return
	end

	bot.LastShot = now
	const aimSpread = BotSettings.AimError + (if bot.MoveDir.Magnitude > 0 then BotSettings.AimErrorMoving else 0)
		+ (if offset.Magnitude > BotSettings.AimFarDistance then BotSettings.AimErrorFar else 0)
	const aimDirection = GunRules.RandomSpread(offset.Unit, aimSpread)

	const hits: { ResolvedHit } = {}
	for _ = 1, math.max(gunData.Bullets, 1) do
		const pellet = GunRules.RandomSpread(aimDirection, gunData.Spread)
		const hit = self:Trace(bot, eye, pellet, gunData.Range)
		if hit then
			table.insert(hits, hit)
		end
	end

	hitService:BroadcastShot(bot, gunData, eye, aimDirection)
	self:PlayShotSound(bot, gunData)
	hitService:ApplyHits(bot, hits, gunData, bot.GunName, eye)
end

function BotService:PlayShotSound(bot: Bot, gunData: GetGun.GunData)
	if WeaponSounds.ShootName(bot.GunName) == "" or not self.Dependencies.NetService:IsRunning() then
		return
	end

	self.Libs.Net.Weapon.ShotSound:fireClient(self.Dependencies.NetService.Audience, {
		ShooterID = bot.GameID,
		GunID = gunData.ID,
	})
end

function BotService:Broadcast(stamp: number)
	const netService = self.Dependencies.NetService
	if not netService:IsRunning() then
		return
	end

	const frames: { BotNet.Frame } = {}
	for _, bot in self.Dependencies.BotRegistryService:All() do
		if not self.Brains[bot] then
			continue
		end
		const gunData = GetGun.ByName(bot.GunName)
		table.insert(frames, {
			GameID = bot.GameID,
			Position = bot.Position,
			LookAt = bot.LookAt,
			State = (if bot.Alive then bot.State else "Dead") :: BotNet.BotState,
			MoveDir = bot.MoveDir,
			WeaponID = if gunData then gunData.ID else 0,
		})
	end

	if #frames == 0 then
		return
	end
	self.Libs.Net.Bot.Frames:fireClient(netService.Audience, { TimeStamp = stamp, Bots = frames })
end

function BotService:Step(dt: number)
	if not self.Active then
		return
	end

	const now = os.clock()
	const stamp = workspace:GetServerTimeNow()
	const combat = self.Dependencies.GameStateService:Can("Combat")
	const filter = self:CharacterFilter()
	const snapshots = self.Dependencies.SnapshotService

	for bot, brain in self.Brains do
		if not bot.Alive then
			continue
		end

		self:Move(bot, brain, filter, dt, combat, now)
		if not bot.Alive then
			continue
		end
		if combat then
			self:Shoot(bot, brain, now)
		end
		self.Dependencies.BotRegistryService:Heal(bot, BotSettings.HealthRegen * dt)

		const gunData = GetGun.ByName(bot.GunName)
		snapshots:RecordFrame(bot.GameID, {
			Position = bot.Position,
			LookAt = bot.LookAt,
			State = bot.State :: any,
			MoveDir = bot.MoveDir,
			WeaponID = if gunData then gunData.ID else 0,
			Timestamp = stamp,
		})
	end

	self:Broadcast(stamp)
end

function BotService:ThinkAll()
	if not self.Active then
		return
	end

	const combat = self.Dependencies.GameStateService:Can("Combat")
	const now = os.clock()
	if not combat then
		for bot, brain in self.Brains do
			brain.Target = nil
			brain.TargetVisible = false
			brain.Strafe = 0
			brain.Mode = "Wander"
			brain.LastSeenAt = nil
			if bot.Alive then
				self:PlanWander(bot, brain, now)
			end
		end
		return
	end

	const filter = self:CharacterFilter()
	for bot, brain in self.Brains do
		if bot.Alive then
			self:Think(bot, brain, filter, now)
		end
	end
end

function BotService:OnPlayerAdded(player: Player)
	self:LoadFriends(player)
	if not self.Active then
		return
	end

	const registry = self.Dependencies.BotRegistryService
	if registry:Count() > self:Desired() then
		const replaced = self:PickReplaced(player)
		if replaced then
			self:RemoveBot(replaced)
		end
	end
	self:Reconcile()
end

function BotService:OnPlayerRemoving(player: Player)
	self.Friends[player] = nil
	if not self.Active then
		return
	end

	task.delay(BotSettings.FillDelay, function()
		self:Reconcile()
	end)
end

BotService:OnInit(function(self)
	self:Setup()

	const playerService = self.Dependencies.PlayerService
	playerService.PlayerAdded:Connect(function(player)
		self:OnPlayerAdded(player)
	end)
	playerService.PlayerRemoving:Connect(function(player)
		self:OnPlayerRemoving(player)
	end)

	self.Dependencies.BotRegistryService.Died:Connect(function(bot)
		bot.MoveDir = Vector2.zero
		self:ScheduleRespawn(bot)
	end)

	self.Dependencies.TeamService.Changed:Connect(function(fighter)
		const bot = BotTypes.AsBot(fighter)
		if bot and self.Brains[bot] then
			self:PublishMember(bot)
		end
	end)

	self.Dependencies.EnvironmentService.MapChanged:Connect(function()
		self.Bounds = nil
		self:RespawnAll()
	end)
end)

BotService:OnStart(function(self)
	for _, player in Players:GetPlayers() do
		self:LoadFriends(player)
	end

	self.Dependencies.ServerRoleService:OnReady(function()
		self.Dependencies.EnvironmentService:OnReady(function()
			self:Activate()
		end)
	end)
end)

BotService:OnTick(function(self)
	self:Step(1 / BotSettings.SimRate)
end, BotSettings.SimRate)

BotService:OnTick(function(self)
	self:ThinkAll()
end, BotSettings.ThinkRate)

return BotService
