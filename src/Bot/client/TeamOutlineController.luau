--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local BotSettings = require(ReplicatedStorage.shared.Bot.BotSettings)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const MODE_ATTRIBUTE = "GameMode"
const TEAM_ATTRIBUTE = "Team"

const TeamOutlineController = Modux.Controller("TeamOutlineController", {
	Require = { "BotController" },
	Priority = 400,
})

function TeamOutlineController:Setup()
	self.Connections = {} :: { [Player]: { RBXScriptConnection } }
end

local function enabled(): boolean
	return typeof(workspace:GetAttribute(MODE_ATTRIBUTE)) == "string"
end

local function colorFor(team: any): Color3
	const colors = BotSettings.HighlightColors
	return if typeof(team) == "string" and colors[team] then colors[team] else colors.None
end

function TeamOutlineController:Apply(model: Model, team: any)
	local highlight = model:FindFirstChild(BotSettings.HighlightName)
	if not enabled() then
		if highlight then
			highlight:Destroy()
		end
		return
	end

	if not highlight or not highlight:IsA("Highlight") then
		const created = Instance.new("Highlight")
		created.Name = BotSettings.HighlightName
		created.DepthMode = Enum.HighlightDepthMode.Occluded
		created.FillTransparency = 1
		created.OutlineTransparency = 0
		created.Adornee = model
		created.Parent = model
		highlight = created
	end
	(highlight :: Highlight).OutlineColor = colorFor(team)
end

function TeamOutlineController:ApplyPlayer(player: Player)
	const character = player.Character
	if player ~= Players.LocalPlayer and character then
		self:Apply(character, player:GetAttribute(TEAM_ATTRIBUTE))
	end
end

function TeamOutlineController:ApplyBot(gameId: number, built: Model?)
	const bots = self.Dependencies.BotController
	const model = built or bots:ModelOf(gameId)
	const member = bots:Find(gameId)
	if model and member then
		self:Apply(model, member.Team)
	end
end

function TeamOutlineController:Refresh()
	for _, player in Players:GetPlayers() do
		self:ApplyPlayer(player)
	end
	for gameId in self.Dependencies.BotController.Members do
		self:ApplyBot(gameId)
	end
end

function TeamOutlineController:Watch(player: Player)
	if player == Players.LocalPlayer or self.Connections[player] then
		return
	end

	self.Connections[player] = {
		player.CharacterAdded:Connect(function()
			self:ApplyPlayer(player)
		end),
		player:GetAttributeChangedSignal(TEAM_ATTRIBUTE):Connect(function()
			self:ApplyPlayer(player)
		end),
	}
	self:ApplyPlayer(player)
end

function TeamOutlineController:Forget(player: Player)
	const connections = self.Connections[player]
	if not connections then
		return
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	self.Connections[player] = nil
end

TeamOutlineController:OnInit(function(self)
	self:Setup()

	const bots = self.Dependencies.BotController
	bots.ModelAdded:Connect(function(gameId, model)
		self:ApplyBot(gameId, model)
	end)
	bots.Changed:Connect(function(gameId)
		self:ApplyBot(gameId)
	end)
end)

TeamOutlineController:OnStart(function(self)
	Players.PlayerAdded:Connect(function(player)
		self:Watch(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Forget(player)
	end)
	for _, player in Players:GetPlayers() do
		self:Watch(player)
	end

	workspace:GetAttributeChangedSignal(MODE_ATTRIBUTE):Connect(function()
		self:Refresh()
	end)
end)

return TeamOutlineController
