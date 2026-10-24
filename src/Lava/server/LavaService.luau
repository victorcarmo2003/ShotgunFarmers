--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local BotSettings = require(ReplicatedStorage.shared.Bot.BotSettings)
local LavaSettings = require(ReplicatedStorage.shared.Lava.LavaSettings)
local Modux = require(ServerScriptService.server.Modux)

const LavaService = Modux.Service("LavaService", {
	Require = { "BotRegistryService", "VitalService" },
	Priority = 260,
})

function LavaService:Setup()
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	self.Params = params :: RaycastParams
end

function LavaService:Mark(instance: Instance)
	if not instance:IsA("BasePart") or instance:FindFirstChildOfClass("PathfindingModifier") then
		return
	end

	const modifier = Instance.new("PathfindingModifier")
	modifier.Label = LavaSettings.PATH_LABEL
	modifier.PassThrough = false
	modifier.Parent = instance
end

function LavaService:Touching(feet: Vector3, lava: { Instance }): boolean
	self.Params.FilterDescendantsInstances = lava
	const origin = feet + Vector3.new(0, LavaSettings.PROBE_RISE, 0)
	return workspace:Raycast(origin, Vector3.new(0, -LavaSettings.PROBE_DEPTH, 0), self.Params) ~= nil
end

function LavaService:IsOnLava(character: Model, lava: { Instance }): boolean
	const root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	const humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return false
	end

	const legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then LavaSettings.R6_LEG_HEIGHT else humanoid.HipHeight
	return self:Touching(root.Position - Vector3.new(0, legs + root.Size.Y / 2, 0), lava)
end

function LavaService:Step()
	const lava = CollectionService:GetTagged(LavaSettings.TAG)
	if #lava == 0 then
		return
	end

	const damage = LavaSettings.DAMAGE_PER_SECOND / LavaSettings.TICK_RATE
	for _, player in Players:GetPlayers() do
		const character = player.Character
		if not character or self.Dependencies.VitalService:IsDead(player) then
			continue
		end
		if not self:IsOnLava(character, lava) then
			continue
		end
		const vital = self.Components.Vital:Get(player)
		if vital and vital.Alive then
			vital:TakeDamage(damage)
		end
	end

	const registry = self.Dependencies.BotRegistryService
	for _, bot in registry:All() do
		if bot.Alive and self:Touching(bot.Position - Vector3.new(0, BotSettings.RootHeight, 0), lava) then
			registry:Damage(bot, damage)
		end
	end
end

LavaService:OnInit(function(self)
	self:Setup()
end)

LavaService:OnStart(function(self)
	for _, instance in CollectionService:GetTagged(LavaSettings.TAG) do
		self:Mark(instance)
	end
	CollectionService:GetInstanceAddedSignal(LavaSettings.TAG):Connect(function(instance)
		self:Mark(instance)
	end)
end)

LavaService:OnTick(function(self)
	self:Step()
end, LavaSettings.TICK_RATE)

return LavaService
