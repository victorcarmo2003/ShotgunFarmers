--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopCatalog = require(ReplicatedStorage.shared.Shop.ShopCatalog)
local SkinCatalog = require(ReplicatedStorage.shared.Shop.SkinCatalog)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Public = {
	Granted: SignalLib.Signal<Player, ShopCatalog.Grant>,
	LastCode: { [Player]: number },
	LastRevive: { [Player]: number },
	Revived: SignalLib.Signal<Player>,
	SkinAttempted: SignalLib.Signal<Player, string, boolean, string>,
	SkinBought: SignalLib.Signal<Player, string, string>,
	SkinEquipped: SignalLib.Signal<Player, string>,
	Used: SignalLib.Signal<Player, ShopCatalog.Grant>,
	Watching: { [Player]: boolean },
	Setup: (self: Public) -> (),
	XpMultiplier: (self: Public, player: Player) -> number,
	SyncAttributes: (self: Public, player: Player) -> (),
	SyncSkinAttributes: (self: Public, player: Player) -> (),
	SkinPatch: (self: Public, profile: any, skin: SkinCatalog.Skin, equip: boolean) -> { [string]: any },
	GrantSkin: (self: Public, player: Player, skin: SkinCatalog.Skin, equip: boolean) -> (),
	BuySkin: (self: Public, player: Player, id: string) -> (boolean, string),
	EquipSkin: (self: Public, player: Player, id: string, equip: boolean) -> (boolean, string),
	OwnsGamepass: (self: Public, player: Player, gamepassId: number) -> boolean,
	CheckGamepasses: (self: Public, player: Player) -> (),
	OnGamepassFinished: (self: Public, player: Player, gamepassId: number, purchased: boolean) -> (),
	RedeemCode: (self: Public, player: Player, raw: string) -> (boolean, string),
	RegisterSkins: (self: Public) -> (),
	Announce: (self: Public, message: string) -> (),
	StartCropDrop: (self: Public, player: Player) -> boolean,
	UsePendingDrop: (self: Public, player: Player) -> (),
	WatchPendingDrops: (self: Public, player: Player) -> (),
	Revive: (self: Public, player: Player) -> boolean,
	Grant: (self: Public, player: Player, item: ShopCatalog.Item) -> (),
	ProcessReceipt: (self: Public, receipt: { [string]: any }) -> Enum.ProductPurchaseDecision,
}

return {}
