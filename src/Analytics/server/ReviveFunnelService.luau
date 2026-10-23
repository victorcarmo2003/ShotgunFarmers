--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ShopCatalog = require(ReplicatedStorage.shared.Shop.ShopCatalog)
local Modux = require(ServerScriptService.server.Modux)

const KILL_WINDOW = 30
const REVIVED_STEP = 6
const REVIVAL_ITEM = "Revival"

const ReviveFunnelService = Modux.Service("ReviveFunnelService", {
	Require = {
		"FunnelService",
		"MatchStatsService",
		"PlayerService",
		"PracticeService",
		"ServerRoleService",
		"ShopService",
		"VitalService",
	},
	Priority = 600,
})

function ReviveFunnelService:Setup()
	self.RevivedAt = {} :: { [Player]: number }
end

function ReviveFunnelService:Enabled(): boolean
	return self.Dependencies.ServerRoleService:IsMatch() and not self.Dependencies.PracticeService:IsPractice()
end

function ReviveFunnelService:Step(player: Player, step: string, fields: { string }?)
	self.Dependencies.FunnelService:Step(player, "Revive", step, fields)
end

function ReviveFunnelService:Drop(player: Player, reason: string)
	self.Dependencies.FunnelService:Drop(player, "Revive", reason)
end

function ReviveFunnelService:OnDied(player: Player)
	self.RevivedAt[player] = nil
	if not self:Enabled() then
		return
	end

	const tokens = player:GetAttribute(ShopCatalog.REVIVAL_ATTRIBUTE)
	self:Step(player, "Died", { if typeof(tokens) == "number" and tokens > 0 then "Tokens" else "Robux" })
end

function ReviveFunnelService:OnRevived(player: Player)
	const session = self.Dependencies.FunnelService:Current(player, "Revive")
	if not session then
		return
	end

	self:Step(player, "Revived")
	self.RevivedAt[player] = os.clock()
	task.delay(KILL_WINDOW, function()
		const current = self.Dependencies.FunnelService:Current(player, "Revive")
		if current and current.Id == session.Id and current.Step == REVIVED_STEP then
			self:Drop(player, "NoKill")
		end
	end)
end

function ReviveFunnelService:OnKill(killer: any)
	if typeof(killer) ~= "Instance" then
		return
	end

	const instance = killer :: Instance
	if not instance:IsA("Player") then
		return
	end

	const player = instance :: Player
	const revivedAt = self.RevivedAt[player]
	if revivedAt and os.clock() - revivedAt <= KILL_WINDOW then
		self.RevivedAt[player] = nil
		self:Step(player, "KillAfterRevive")
	end
end

function ReviveFunnelService:OnSpawned(player: Player)
	const session = self.Dependencies.FunnelService:Current(player, "Revive")
	if session and session.Step < REVIVED_STEP then
		self:Drop(player, "Respawned")
	end
end

function ReviveFunnelService:OnPromptFinished(userId: number, productId: number, purchased: boolean)
	const item = ShopCatalog.ById(REVIVAL_ITEM)
	const player = Players:GetPlayerByUserId(userId)
	if purchased or not player or not item or item.ProductId ~= productId then
		return
	end
	self:Drop(player, "PromptClosed")
end

ReviveFunnelService:OnInit(function(self)
	self:Setup()
end)

ReviveFunnelService:OnStart(function(self)
	self.Dependencies.FunnelService:Validate("Revive", function(player)
		return self.Dependencies.VitalService:IsDead(player)
	end)

	self.Dependencies.VitalService.Died:Connect(function(player)
		self:OnDied(player)
	end)

	self.Dependencies.ShopService.Granted:Connect(function(player, grant)
		if grant == "Revival" then
			self:Step(player, "Purchased")
		end
	end)

	self.Dependencies.ShopService.Revived:Connect(function(player)
		self:OnRevived(player)
	end)

	self.Dependencies.MatchStatsService.Killed:Connect(function(killer)
		self:OnKill(killer)
	end)

	self.Dependencies.PlayerService.CharacterAdded:Connect(function(player)
		self:OnSpawned(player)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.RevivedAt[player] = nil
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		self:OnPromptFinished(userId, productId, purchased)
	end)
end)

return ReviveFunnelService
