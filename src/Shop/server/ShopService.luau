--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ShopCatalog = require(ReplicatedStorage.shared.Shop.ShopCatalog)
local SkinCatalog = require(ReplicatedStorage.shared.Shop.SkinCatalog)
local CodeCatalog = require(ReplicatedStorage.shared.Shop.CodeCatalog)
local CareerSettings = require(ReplicatedStorage.shared.Career.CareerSettings)
local Progression = require(ReplicatedStorage.shared.Career.Progression)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

const PURCHASE_HISTORY = 100
const TOKEN_MAX = 999
const PENDING_DROP_POLL = 2
const REVIVE_COOLDOWN = 1
const CODE_COOLDOWN = 1
const PRACTICE_MODE = "Practice"

const ShopService = Modux.Service("ShopService", {
	Require = { "NetService", "PlayerService", "ProfileService", "SpawnService", "VitalService", "WeaponSpawnService" },
	Priority = 650,
})

function ShopService:Setup()
	self.LastRevive = {} :: { [Player]: number }
	self.Watching = {} :: { [Player]: boolean }
	self.LastCode = {} :: { [Player]: number }
	self.Granted = self.Libs.Signal.new() :: SignalLib.Signal<Player, ShopCatalog.Grant>
	self.Revived = self.Libs.Signal.new() :: SignalLib.Signal<Player>
	self.Used = self.Libs.Signal.new() :: SignalLib.Signal<Player, ShopCatalog.Grant>
	self.SkinAttempted = self.Libs.Signal.new() :: SignalLib.Signal<Player, string, boolean, string>
	self.SkinBought = self.Libs.Signal.new() :: SignalLib.Signal<Player, string, string>
	self.SkinEquipped = self.Libs.Signal.new() :: SignalLib.Signal<Player, string>
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
	self:SyncSkinAttributes(player)
end

function ShopService:SyncSkinAttributes(player: Player)
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile then
		return
	end

	const equipped = profile.EquippedSkins()
	for _, skin in SkinCatalog.Skins do
		player:SetAttribute(SkinCatalog.AttributeName(skin.Gun), equipped[skin.Gun])
	end
end

function ShopService:SkinPatch(profile: any, skin: SkinCatalog.Skin, equip: boolean): { [string]: any }
	const owned = table.clone(profile.OwnedSkins() :: { [string]: boolean })
	owned[skin.Id] = true
	const equipped = table.clone(profile.EquippedSkins() :: { [string]: string })
	if equip then
		equipped[skin.Gun] = skin.Id
	end
	return { OwnedSkins = owned, EquippedSkins = equipped }
end

function ShopService:GrantSkin(player: Player, skin: SkinCatalog.Skin, equip: boolean)
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile then
		return
	end

	self.Dependencies.ProfileService:Update(player, self:SkinPatch(profile, skin, equip) :: any)
	self:SyncAttributes(player)
end

function ShopService:BuySkin(player: Player, id: string): (boolean, string)
	const skin = SkinCatalog.ById(id)
	const profile = self.Dependencies.ProfileService:Get(player)
	if not skin or not profile then
		return false, "Item unavailable"
	end
	if profile.OwnedSkins()[skin.Id] then
		return false, "Already owned"
	end

	const balance = profile.Gems()
	if balance < skin.CoinPrice then
		return false, "Not enough coins"
	end

	const patch = self:SkinPatch(profile, skin, true)
	patch.Gems = balance - skin.CoinPrice
	patch.GemsSpent = profile.GemsSpent() + skin.CoinPrice
	self.Dependencies.ProfileService:Update(player, patch :: any)
	self:SyncAttributes(player)
	self.Dependencies.ProfileService:Save(player)
	self.SkinBought:Fire(player, skin.Id, "Gems")
	return true, ""
end

function ShopService:EquipSkin(player: Player, id: string, equip: boolean): (boolean, string)
	const skin = SkinCatalog.ById(id)
	const profile = self.Dependencies.ProfileService:Get(player)
	if not skin or not profile then
		return false, "Item unavailable"
	end
	if not profile.OwnedSkins()[skin.Id] then
		return false, "Not owned"
	end

	const equipped = table.clone(profile.EquippedSkins() :: { [string]: string })
	equipped[skin.Gun] = if equip then skin.Id else nil
	self.Dependencies.ProfileService:Update(player, { EquippedSkins = equipped } :: any)
	self:SyncAttributes(player)
	self.Dependencies.ProfileService:Save(player)
	if equip then
		self.SkinEquipped:Fire(player, skin.Id)
	end
	return true, ""
end

function ShopService:OwnsGamepass(player: Player, gamepassId: number): boolean
	const ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	return ok and owns == true
end

function ShopService:CheckGamepasses(player: Player)
	task.spawn(function()
		for _, skin in SkinCatalog.Skins do
			const profile = self.Dependencies.ProfileService:Get(player)
			if not profile then
				return
			end
			if skin.GamepassId > 0 and not profile.OwnedSkins()[skin.Id] and self:OwnsGamepass(player, skin.GamepassId) then
				self:GrantSkin(player, skin, false)
			end
		end
	end)
end

function ShopService:OnGamepassFinished(player: Player, gamepassId: number, purchased: boolean)
	const skin = SkinCatalog.ByGamepass(gamepassId)
	const profile = self.Dependencies.ProfileService:Get(player)
	if not purchased or not skin or not profile or profile.OwnedSkins()[skin.Id] then
		return
	end

	const patch = self:SkinPatch(profile, skin, true)
	patch.RobuxSpent = profile.RobuxSpent() + skin.RobuxPrice
	self.Dependencies.ProfileService:Update(player, patch :: any)
	self:SyncAttributes(player)
	self.Dependencies.ProfileService:Save(player)
	self.SkinBought:Fire(player, skin.Id, "Robux")
end

function ShopService:RedeemCode(player: Player, raw: string): (boolean, string)
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile then
		return false, "Try again"
	end

	const now = os.clock()
	const last = self.LastCode[player]
	if last and now - last < CODE_COOLDOWN then
		return false, "Slow down"
	end
	self.LastCode[player] = now

	const code = CodeCatalog.Normalize(raw)
	const reward = CodeCatalog.Codes[code]
	if not reward then
		return false, "Invalid code"
	end

	const redeemed = table.clone(profile.RedeemedCodes() :: { [string]: boolean })
	if redeemed[code] then
		return false, "Code already used"
	end
	redeemed[code] = true

	const patch: { [string]: any } = { RedeemedCodes = redeemed }
	const parts: { string } = {}

	if reward.Gems then
		patch.Gems = math.min(profile.Gems() + reward.Gems, CareerSettings.GEMS_MAX)
		table.insert(parts, `{reward.Gems} coins`)
	end
	if reward.Xp then
		const level, xp = Progression.Apply(profile.Level(), profile.Xp(), reward.Xp)
		patch.Level = level
		patch.Xp = xp
		table.insert(parts, `{reward.Xp} XP`)
	end

	self.Dependencies.ProfileService:Update(player, patch :: any)
	self.Dependencies.ProfileService:Save(player)
	return true, `You received {table.concat(parts, " + ")}!`
end

function ShopService:RegisterSkins()
	const net = self.Libs.Net.Shop

	net.BuySkin:onServer(function(request, player)
		const accepted, reason = self:BuySkin(player, request.Id)
		self.SkinAttempted:Fire(player, request.Id, accepted, reason)
		return { Accepted = accepted, Reason = reason }
	end)

	net.EquipSkin:onServer(function(request, player)
		const accepted, reason = self:EquipSkin(player, request.Id, request.Equip)
		return { Accepted = accepted, Reason = reason }
	end)

	net.RedeemCode:onServer(function(request, player)
		const accepted, reason = self:RedeemCode(player, request.Code)
		return { Accepted = accepted, Reason = reason }
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, purchased)
		self:OnGamepassFinished(player, gamepassId, purchased)
	end)
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
		self.Used:Fire(player, "CropDrop")
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
	self.Revived:Fire(player)
	self.Used:Fire(player, "Revival")
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
	self.Granted:Fire(player, item.Grant)
	if item.Grant == "DoubleXp" then
		self.Used:Fire(player, "DoubleXp")
	end

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

	self:RegisterSkins()

	self.Dependencies.ProfileService.Loaded:Connect(function(player)
		self:SyncAttributes(player)
		self:WatchPendingDrops(player)
		self:CheckGamepasses(player)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.LastRevive[player] = nil
		self.Watching[player] = nil
		self.LastCode[player] = nil
	end)
end)

return ShopService
