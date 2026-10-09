--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ShopCatalog = require(ReplicatedStorage.shared.Shop.ShopCatalog)
local Modux = require(ServerScriptService.server.Modux)

const GEMS_MAX = 1000000000
const PURCHASE_HISTORY = 100

const ShopService = Modux.Service("ShopService", {
	Require = { "PlayerService", "ProfileService" },
	Priority = 650,
})

function ShopService:Setup()
	self.Warned = false :: boolean
end

function ShopService:HasPass(player: Player, id: string): boolean
	const profile = self.Dependencies.ProfileService:Get(player)
	return profile ~= nil and profile.Gamepasses()[id] == true
end

function ShopService:GemMultiplier(player: Player): number
	local multiplier = 1
	for _, item in ShopCatalog.Items do
		if item.Kind == "Pass" and item.GemMultiplier and self:HasPass(player, item.Id) then
			multiplier *= item.GemMultiplier
		end
	end
	return multiplier
end

function ShopService:GrantPass(player: Player, id: string)
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile or profile.Gamepasses()[id] then
		return
	end

	const passes = table.clone(profile.Gamepasses())
	passes[id] = true
	profile.Gamepasses(passes)
end

function ShopService:SyncPasses(player: Player)
	for _, item in ShopCatalog.Items do
		if item.Kind ~= "Pass" or item.AssetId == 0 then
			continue
		end

		const ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.AssetId)
		end)
		if ok and owns and player.Parent == Players then
			self:GrantPass(player, item.Id)
		end
	end
end

function ShopService:ProcessReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	const player = Players:GetPlayerByUserId(receipt.PlayerId)
	const profile = if player then self.Dependencies.ProfileService:Get(player) else nil
	if not player or not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	const purchaseId = tostring(receipt.PurchaseId)
	const history = profile.PurchaseIds()
	if table.find(history, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	const item = ShopCatalog.ByAsset("Product", receipt.ProductId)
	if not item or not item.Gems then
		warn(`[ShopService] ProductId {receipt.ProductId} nao esta no ShopCatalog`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	const nextHistory = table.clone(history)
	table.insert(nextHistory, purchaseId)
	while #nextHistory > PURCHASE_HISTORY do
		table.remove(nextHistory, 1)
	end

	self.Dependencies.ProfileService:Update(player, {
		Gems = math.min(profile.Gems() + item.Gems, GEMS_MAX),
		RobuxSpent = profile.RobuxSpent() + (receipt.CurrencySpent or 0),
		PurchaseIds = nextHistory,
	})
	self.Dependencies.ProfileService:Save(player)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService:WarnMissingIds()
	for _, item in ShopCatalog.Items do
		if item.AssetId == 0 then
			warn("[ShopService] ShopCatalog tem itens com AssetId = 0; crie os DevProducts/Gamepasses no Creator Hub")
			return
		end
	end
end

ShopService:OnInit(function(self)
	self:Setup()

	MarketplaceService.ProcessReceipt = function(receipt)
		return self:ProcessReceipt(receipt)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if not purchased then
			return
		end

		const item = ShopCatalog.ByAsset("Pass", passId)
		if item then
			self:GrantPass(player, item.Id)
		end
	end)

	self.Dependencies.ProfileService.Loaded:Connect(function(player)
		task.spawn(function()
			self:SyncPasses(player)
		end)
	end)
end)

ShopService:OnStart(function(self)
	self:WarnMissingIds()
end)

return ShopService
