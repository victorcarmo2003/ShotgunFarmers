--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ShopCatalog = require(ReplicatedStorage.shared.Shop.ShopCatalog)
local Modux = require(ServerScriptService.server.Modux)

const PURCHASE_HISTORY = 100
const TOKEN_MAX = 999
const PENDING_DROP_POLL = 2
const REVIVE_COOLDOWN = 1
const PRACTICE_MODE = "Practice"

const ShopService = Modux.Service("ShopService", {
	Require = { "NetService", "PlayerService", "ProfileService", "SpawnService", "VitalService", "WeaponSpawnService" },
	Priority = 650,
})

function ShopService:Setup()
	self.LastRevive = {} :: { [Player]: number }
	self.Watching = {} :: { [Player]: boolean }
end

function ShopService:XpMultiplier(player: Player): number
	const profile = self.Dependencies.ProfileService:Get(player)
	if profile and profile.XpBoostEnds() > os.time() then
		return ShopCatalog.XP_BOOST_MULTIPLIER
	end
	return 1
end

function ShopService:SyncAttributes(player: Player)
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile then
		return
	end

	player:SetAttribute(ShopCatalog.REVIVAL_ATTRIBUTE, profile.RevivalTokens())
	player:SetAttribute(ShopCatalog.XP_BOOST_ATTRIBUTE, profile.XpBoostEnds())
	player:SetAttribute(ShopCatalog.CROP_DROP_ATTRIBUTE, profile.CropDrops())
end

function ShopService:Announce(message: string)
	const netService = self.Dependencies.NetService
	if netService:IsRunning() then
		self.Libs.Net.Shop.Announce:fireClient(netService.Audience, { Message = string.sub(message, 1, 120) })
	end
end

function ShopService:StartCropDrop(player: Player): boolean
	const started = self.Dependencies.WeaponSpawnService:CropDrop(
		ShopCatalog.CROP_DROP_SECONDS,
		ShopCatalog.CROP_DROP_INTERVAL,
		ShopCatalog.CROP_DROP_MAX
	)
	if started then
		self:Announce(`{player.DisplayName} started a CROP DROP!`)
	end
	return started
end

function ShopService:UsePendingDrop(player: Player)
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile or profile.CropDrops() <= 0 then
		return
	end

	if self:StartCropDrop(player) then
		profile.CropDrops(profile.CropDrops() - 1)
		self:SyncAttributes(player)
	end
end

function ShopService:WatchPendingDrops(player: Player)
	if self.Watching[player] then
		return
	end
	self.Watching[player] = true

	task.spawn(function()
		while player.Parent == Players and self.Watching[player] do
			const profile = self.Dependencies.ProfileService:Get(player)
			if profile and profile.CropDrops() > 0 and self.Dependencies.WeaponSpawnService:IsActive() then
				self:UsePendingDrop(player)
			end
			task.wait(PENDING_DROP_POLL)
		end
	end)
end

function ShopService:Revive(player: Player): boolean
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile or profile.RevivalTokens() <= 0 or not self.Dependencies.VitalService:IsDead(player) then
		return false
	end
	if workspace:GetAttribute("GameMode") == PRACTICE_MODE then
		return false
	end

	const now = os.clock()
	const last = self.LastRevive[player]
	if last and now - last < REVIVE_COOLDOWN then
		return false
	end
	self.LastRevive[player] = now

	profile.RevivalTokens(profile.RevivalTokens() - 1)
	self:SyncAttributes(player)
	self.Dependencies.SpawnService:Respawn(player, 0)
	return true
end

function ShopService:Grant(player: Player, item: ShopCatalog.Item)
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile then
		return
	end

	if item.Grant == "DoubleXp" then
		profile.XpBoostEnds(math.max(profile.XpBoostEnds(), os.time()) + ShopCatalog.XP_BOOST_SECONDS)
	elseif item.Grant == "Revival" then
		profile.RevivalTokens(math.min(profile.RevivalTokens() + 1, TOKEN_MAX))
	elseif item.Grant == "CropDrop" then
		profile.CropDrops(math.min(profile.CropDrops() + 1, TOKEN_MAX))
	end
	self:SyncAttributes(player)

	if item.Grant == "Revival" and self.Dependencies.VitalService:IsDead(player) then
		self:Revive(player)
	elseif item.Grant == "CropDrop" then
		self:UsePendingDrop(player)
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

	const item = ShopCatalog.ByProduct(receipt.ProductId)
	if not item then
		warn(`[ShopService] ProductId {receipt.ProductId} nao esta no ShopCatalog`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	const nextHistory = table.clone(history)
	table.insert(nextHistory, purchaseId)
	while #nextHistory > PURCHASE_HISTORY do
		table.remove(nextHistory, 1)
	end

	self.Dependencies.ProfileService:Update(player, {
		RobuxSpent = profile.RobuxSpent() + (receipt.CurrencySpent or 0),
		PurchaseIds = nextHistory,
	})
	self:Grant(player, item)
	self.Dependencies.ProfileService:Save(player)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

ShopService:OnInit(function(self)
	self:Setup()

	MarketplaceService.ProcessReceipt = function(receipt)
		return self:ProcessReceipt(receipt)
	end

	self.Libs.Net.Shop.Revive:onServer(function(_, player)
		self:Revive(player)
	end)

	self.Dependencies.ProfileService.Loaded:Connect(function(player)
		self:SyncAttributes(player)
		self:WatchPendingDrops(player)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.LastRevive[player] = nil
		self.Watching[player] = nil
	end)
end)

return ShopService
