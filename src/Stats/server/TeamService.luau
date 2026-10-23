--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GameModes = require(ReplicatedStorage.shared.Match.GameModes)
local MatchSettings = require(ReplicatedStorage.shared.Match.MatchSettings)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local BotTypes = require(ServerScriptService.server.Bot.BotTypes)
local Modux = require(ServerScriptService.server.Modux)

type Fighter = BotTypes.Fighter

const TeamService = Modux.Service("TeamService", {
	Require = { "BotRegistryService", "PlayerService", "ServerRoleService" },
	Priority = 785,
})

function TeamService:Setup()
	self.Teams = {} :: { [Fighter]: string }
	self.Changed = self.Libs.Signal.new() :: SignalLib.Signal<Fighter, string?>
end

function TeamService:IsTeamMode(): boolean
	const roleService = self.Dependencies.ServerRoleService
	if not roleService.IsReady or not roleService:IsMatch() then
		return false
	end

	const config = roleService:GetConfig()
	if not config then
		return false
	end

	const mode = GameModes.Modes[config.Mode]
	return mode ~= nil and mode.Teams
end

function TeamService:Count(teamName: string): number
	local total = 0
	for _, assigned in self.Teams do
		if assigned == teamName then
			total += 1
		end
	end
	return total
end

function TeamService:PickTeam(): string
	const names = MatchSettings.TeamNames
	local best = names[1]
	local bestCount = self:Count(best)
	local ties = 1

	for index = 2, #names do
		const count = self:Count(names[index])
		if count < bestCount then
			best = names[index]
			bestCount = count
			ties = 1
		elseif count == bestCount then
			ties += 1
			if math.random(1, ties) == 1 then
				best = names[index]
			end
		end
	end

	return best
end

function TeamService:Assign(fighter: Fighter)
	if self.Teams[fighter] ~= nil or not self:IsTeamMode() then
		return
	end

	const player = BotTypes.AsPlayer(fighter)
	if player and not player:IsDescendantOf(Players) then
		return
	end

	const teamName = self:PickTeam()
	self.Teams[fighter] = teamName
	if player then
		player:SetAttribute("Team", teamName)
	end
	self.Changed:Fire(fighter, teamName)
end

function TeamService:Release(fighter: Fighter)
	if self.Teams[fighter] == nil then
		return
	end

	self.Teams[fighter] = nil
	const player = BotTypes.AsPlayer(fighter)
	if player then
		player:SetAttribute("Team", nil)
	end
	self.Changed:Fire(fighter, nil)
end

function TeamService:GetTeam(fighter: Fighter): string?
	self:Assign(fighter)
	return self.Teams[fighter]
end

function TeamService:SameTeam(first: Fighter, second: Fighter): boolean
	const firstTeam = self:GetTeam(first)
	return firstTeam ~= nil and firstTeam == self:GetTeam(second)
end

TeamService:OnInit(function(self)
	self:Setup()

	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
		self:Assign(player)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Release(player)
	end)

	self.Dependencies.BotRegistryService.Removing:Connect(function(bot)
		self:Release(bot)
	end)
end)

TeamService:OnStart(function(self)
	self.Dependencies.ServerRoleService:OnReady(function()
		for _, player in Players:GetPlayers() do
			self:Assign(player)
		end
	end)
end)

return TeamService
