--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local LoadoutSettings = require(ReplicatedStorage.shared.Weapon.LoadoutSettings)
local Maps = require(ReplicatedStorage.shared.Match.Maps)
local PracticeCatalog = require(ReplicatedStorage.shared.Practice.PracticeCatalog)
local VoteMaps = require(ReplicatedStorage.shared.Round.VoteMaps)
local Modux = require(ServerScriptService.server.Modux)

const MIN_OPTIONS = 2

const MapVoteService = Modux.Service("MapVoteService", {
	Require = {
		"DayNightService",
		"EnvironmentService",
		"NetService",
		"PlayerService",
		"RoundService",
		"ServerRoleService",
		"SpawnService",
		"VitalService",
	},
	Priority = 590,
})

function MapVoteService:Setup()
	self.Open = false :: boolean
	self.Options = {} :: { string }
	self.Votes = {} :: { [Player]: number }
	self.Counts = {} :: { number }
	self.Pool = {} :: { GetGun.GunNames }
	self.Wanted = {} :: { [Player]: GetGun.GunNames }
	self.Granted = {} :: { [Player]: boolean }
end

function MapVoteService:ModeName(): string?
	const roleService = self.Dependencies.ServerRoleService
	const config = roleService:GetConfig()
	return if roleService:IsMatch() and config then config.Mode else nil
end

function MapVoteService:ShouldVote(): boolean
	const config = self.Dependencies.ServerRoleService:GetConfig()
	const modeName = self:ModeName()
	if not config or not modeName or modeName == PracticeCatalog.MODE or config.Ranked then
		return false
	end

	return #VoteMaps.list(modeName) >= MIN_OPTIONS and #Players:GetPlayers() > 0
end

function MapVoteService:BuildPool()
	table.clear(self.Pool)
	for _, name in LoadoutSettings.StartingWeaponPool do
		const gunData = GetGun.ByName(name)
		if not gunData then
			warn(`[MapVoteService] arma inicial "{name}" nao existe em GunsData; descartada`)
		elseif gunData.Disabled then
			warn(`[MapVoteService] arma inicial "{name}" esta Disabled; descartada`)
		elseif gunData.PoseKind ~= "Firearm" then
			warn(`[MapVoteService] arma inicial "{name}" nao e Firearm; descartada`)
		else
			table.insert(self.Pool, name :: any)
		end
	end
end

function MapVoteService:StartingEnabled(): boolean
	const modeName = self:ModeName()
	return modeName ~= nil and modeName ~= PracticeCatalog.MODE
end

function MapVoteService:Roll(): GetGun.GunNames?
	if #self.Pool == 0 then
		return nil
	end

	return self.Pool[math.random(1, #self.Pool)]
end

function MapVoteService:Deal(player: Player)
	self.Granted[player] = true
	self.Wanted[player] = self:Roll()
end

function MapVoteService:TakeStart(player: Player): GetGun.GunNames?
	if not self:StartingEnabled() then
		return nil
	end

	if not self.Granted[player] then
		self:Deal(player)
	end

	return self.Wanted[player]
end

function MapVoteService:DealAll()
	table.clear(self.Granted)
	table.clear(self.Wanted)
	for _, player in Players:GetPlayers() do
		self:Deal(player)
	end
end

function MapVoteService:ClearSeeds()
	const seeds = workspace:FindFirstChild("Seeds")
	if seeds then
		seeds:ClearAllChildren()
	end
end

function MapVoteService:Tally()
	const counts = table.create(#self.Options, 0)
	for _, option in self.Votes do
		counts[option] = (counts[option] or 0) + 1
	end

	if self.Dependencies.NetService:IsRunning() then
		for index = 1, #self.Options do
			const count = math.min(counts[index] or 0, 255)
			if self.Counts[index] ~= count then
				self.Libs.Net.Round.VoteOptions:update(index, { Votes = count })
			end
		end
	end

	for index = 1, #self.Options do
		counts[index] = math.min(counts[index] or 0, 255)
	end
	self.Counts = counts
end

function MapVoteService:OpenVote()
	if self.Open or not self:ShouldVote() then
		return
	end

	const modeName = self:ModeName()
	if not modeName then
		return
	end

	self.Open = true
	self.Options = VoteMaps.list(modeName)
	table.clear(self.Votes)
	self.Counts = table.create(#self.Options, 0)

	if self.Dependencies.NetService:IsRunning() then
		for index = 1, #self.Options do
			self.Libs.Net.Round.VoteOptions:add(index, { Votes = 0 })
		end
	end
end

function MapVoteService:Cast(player: Player, option: number)
	if not self.Open or self.Dependencies.RoundService.Status() ~= "Vote" then
		return
	end

	if option < 1 or option > #self.Options or self.Votes[player] == option then
		return
	end

	self.Votes[player] = option
	self:Tally()
end

function MapVoteService:Pick(): number
	const counts = table.create(#self.Options, 0)
	for _, option in self.Votes do
		counts[option] = (counts[option] or 0) + 1
	end

	local best = 0
	for index = 1, #self.Options do
		best = math.max(best, counts[index] or 0)
	end

	const config = self.Dependencies.ServerRoleService:GetConfig()
	const current = if config then config.Map else nil

	const candidates: { number } = {}
	for index = 1, #self.Options do
		if best > 0 and (counts[index] or 0) == best then
			table.insert(candidates, index)
		elseif best == 0 and self.Options[index] ~= current then
			table.insert(candidates, index)
		end
	end

	if #candidates == 0 then
		for index = 1, #self.Options do
			table.insert(candidates, index)
		end
	end

	return candidates[math.random(1, #candidates)]
end

function MapVoteService:Conclude(): string?
	if not self.Open then
		return nil
	end

	const winnerIndex = self:Pick()
	const winner = self.Options[winnerIndex]
	const optionCount = #self.Options

	if self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.Round.VoteResult:fireClient(self.Dependencies.NetService.Audience, { Option = winnerIndex })
		for index = 1, optionCount do
			self.Libs.Net.Round.VoteOptions:remove(index)
		end
	end

	self.Open = false
	table.clear(self.Options)
	table.clear(self.Votes)
	table.clear(self.Counts)
	return winner
end

function MapVoteService:Apply(mapName: string)
	const roleService = self.Dependencies.ServerRoleService
	const config = roleService:GetConfig()
	if not config or config.Map == mapName then
		return
	end

	if not self.Dependencies.EnvironmentService:SwapMap(mapName) then
		warn(`[MapVoteService] troca para "{mapName}" falhou; mantendo "{config.Map}"`)
		return
	end

	roleService:SetMap(mapName)

	if Maps[mapName].DayCycle then
		self.Dependencies.DayNightService:StartCycle()
	else
		self.Dependencies.DayNightService:StopCycle()
	end
end

function MapVoteService:BeginRound()
	if not self.Dependencies.ServerRoleService:IsMatch() then
		return
	end

	const winner = self:Conclude()
	if winner then
		self:Apply(winner)
	end

	if not self:StartingEnabled() then
		return
	end

	self:ClearSeeds()
	self:DealAll()
	self.Dependencies.SpawnService:RespawnAll()
end

function MapVoteService:Forget(player: Player)
	self.Wanted[player] = nil
	self.Granted[player] = nil

	if self.Votes[player] ~= nil then
		self.Votes[player] = nil
		if self.Open then
			self:Tally()
		end
	end
end

MapVoteService:OnInit(function(self)
	self:Setup()
	self:BuildPool()

	self.Dependencies.RoundService:SetSkip("Vote", function()
		return not self:ShouldVote()
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Forget(player)
	end)

	self.Dependencies.VitalService.Died:Connect(function(victim)
		self.Wanted[victim] = nil
	end)

	self.Libs.Net.Round.CastVote:onServer(function(request, player)
		self:Cast(player, request.Option)
	end)
end)

MapVoteService:OnStart(function(self)
	self.Libs.Charm.subscribe(self.Dependencies.RoundService.Status, function(status, previous)
		if status == "Vote" then
			self:OpenVote()
		elseif status == "Starting" and previous ~= "Starting" then
			task.spawn(function()
				self:BeginRound()
			end)
		end
	end)
end)

return MapVoteService
