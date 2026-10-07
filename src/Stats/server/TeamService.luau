--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GameModes = require(ReplicatedStorage.shared.Match.GameModes)
local MatchSettings = require(ReplicatedStorage.shared.Match.MatchSettings)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

const TeamService = Modux.Service("TeamService", {
	Require = { "PlayerService", "ServerRoleService" },
	Priority = 785,
})

function TeamService:Setup()
	self.Teams = {} :: { [Player]: string }
	self.Changed = self.Libs.Signal.new() :: SignalLib.Signal<Player, string?>
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

function TeamService:Assign(player: Player)
	if self.Teams[player] ~= nil or not player:IsDescendantOf(Players) or not self:IsTeamMode() then
		return
	end

	const teamName = self:PickTeam()
	self.Teams[player] = teamName
	player:SetAttribute("Team", teamName)
	self.Changed:Fire(player, teamName)
end

function TeamService:Release(player: Player)
	if self.Teams[player] == nil then
		return
	end

	self.Teams[player] = nil
	player:SetAttribute("Team", nil)
	self.Changed:Fire(player, nil)
end

function TeamService:GetTeam(player: Player): string?
	self:Assign(player)
	return self.Teams[player]
end

function TeamService:SameTeam(first: Player, second: Player): boolean
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
end)

TeamService:OnStart(function(self)
	self.Dependencies.ServerRoleService:OnReady(function()
		for _, player in Players:GetPlayers() do
			self:Assign(player)
		end
	end)
end)

return TeamService
