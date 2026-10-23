--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ShopCatalog = require(ReplicatedStorage.shared.Shop.ShopCatalog)
local Modux = require(ServerScriptService.server.Modux)

const MARK_PREFIX = "Bought"

const ShopFunnelService = Modux.Service("ShopFunnelService", {
	Require = { "FunnelService", "ShopService" },
	Priority = 600,
})

function ShopFunnelService:Step(player: Player, step: string, fields: { string }?)
	self.Dependencies.FunnelService:Step(player, "RobuxShop", step, fields)
end

function ShopFunnelService:OnGranted(player: Player, grant: ShopCatalog.Grant)
	const funnel = self.Dependencies.FunnelService
	if not funnel:Current(player, "RobuxShop") then
		return
	end

	funnel:Mark(player, `{MARK_PREFIX}{grant}`)
	self:Step(player, "Purchased", { grant })
end

function ShopFunnelService:OnUsed(player: Player, grant: ShopCatalog.Grant)
	const funnel = self.Dependencies.FunnelService
	const boughtAt = funnel:TakeMark(player, `{MARK_PREFIX}{grant}`)
	if not boughtAt then
		return
	end

	const waited = math.max(os.time() - boughtAt, 0)
	funnel:Event(player, "ItemUseWait", waited, { grant })
	self:Step(player, "ItemUsed", { grant, tostring(waited) })
end

function ShopFunnelService:OnPromptFinished(userId: number, productId: number, purchased: boolean)
	const player = Players:GetPlayerByUserId(userId)
	const item = ShopCatalog.ByProduct(productId)
	if purchased or not player or not item then
		return
	end
	self.Dependencies.FunnelService:Drop(player, "RobuxShop", "PromptClosed", { item.Id })
end

ShopFunnelService:OnStart(function(self)
	const shop = self.Dependencies.ShopService
	shop.Granted:Connect(function(player, grant)
		self:OnGranted(player, grant)
	end)

	shop.Used:Connect(function(player, grant)
		self:OnUsed(player, grant)
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		self:OnPromptFinished(userId, productId, purchased)
	end)
end)

return ShopFunnelService
