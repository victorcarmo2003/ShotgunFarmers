--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopCatalog = require(ReplicatedStorage.shared.Shop.ShopCatalog)

export type Public = {
	LastRevive: { [Player]: number },
	Watching: { [Player]: boolean },
	Setup: (self: Public) -> (),
	XpMultiplier: (self: Public, player: Player) -> number,
	SyncAttributes: (self: Public, player: Player) -> (),
	Announce: (self: Public, message: string) -> (),
	StartCropDrop: (self: Public, player: Player) -> boolean,
	UsePendingDrop: (self: Public, player: Player) -> (),
	WatchPendingDrops: (self: Public, player: Player) -> (),
	Revive: (self: Public, player: Player) -> boolean,
	Grant: (self: Public, player: Player, item: ShopCatalog.Item) -> (),
	ProcessReceipt: (self: Public, receipt: { [string]: any }) -> Enum.ProductPurchaseDecision,
}

return {}
