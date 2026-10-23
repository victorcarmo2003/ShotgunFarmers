--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopCatalog = require(ReplicatedStorage.shared.Shop.ShopCatalog)

export type Public = {
	Step: (self: Public, player: Player, step: string, fields: { string }?) -> (),
	OnGranted: (self: Public, player: Player, grant: ShopCatalog.Grant) -> (),
	OnUsed: (self: Public, player: Player, grant: ShopCatalog.Grant) -> (),
	OnPromptFinished: (self: Public, userId: number, productId: number, purchased: boolean) -> (),
}

return {}
