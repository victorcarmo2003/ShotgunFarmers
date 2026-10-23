--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SkinCatalog = require(ReplicatedStorage.shared.Shop.SkinCatalog)
local Modux = require(ServerScriptService.server.Modux)

const SkinFunnelService = Modux.Service("SkinFunnelService", {
	Require = { "CareerService", "FunnelService", "ProfileService", "ShopService" },
	Priority = 600,
})

function SkinFunnelService:Step(player: Player, step: string, fields: { string }?)
	self.Dependencies.FunnelService:Step(player, "Skins", step, fields)
end

function SkinFunnelService:OnAttempt(player: Player, id: string, accepted: boolean, reason: string)
	self:Step(player, "TriedBuy", { id, "Gems" })
	if not accepted then
		self.Dependencies.FunnelService:Event(player, "SkinBuyFailed", 1, { reason, id })
	end
end

function SkinFunnelService:OnBought(player: Player, id: string, currency: string)
	self:Step(player, "Bought", { id, currency })
	self:Step(player, "Equipped", { id })
end

function SkinFunnelService:OnResolved(player: Player)
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile then
		return
	end

	local count = 0
	for _ in profile.EquippedSkins() :: { [string]: string } do
		count += 1
	end
	if count > 0 then
		self:Step(player, "PlayedWithSkin", { tostring(count) })
	end
end

SkinFunnelService:OnStart(function(self)
	self.Dependencies.FunnelService:Validate("Skins", function(_, step, detail)
		if step ~= "TriedBuy" then
			return true
		end
		const skin = SkinCatalog.ById(detail)
		return skin ~= nil and skin.GamepassId > 0
	end)

	const shop = self.Dependencies.ShopService
	shop.SkinAttempted:Connect(function(player, id, accepted, reason)
		self:OnAttempt(player, id, accepted, reason)
	end)

	shop.SkinBought:Connect(function(player, id, currency)
		self:OnBought(player, id, currency)
	end)

	shop.SkinEquipped:Connect(function(player, id)
		self:Step(player, "Equipped", { id })
	end)

	self.Dependencies.CareerService.Resolved:Connect(function(player)
		self:OnResolved(player)
	end)
end)

return SkinFunnelService
