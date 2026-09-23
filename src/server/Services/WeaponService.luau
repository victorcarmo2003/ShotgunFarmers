local CollectionService = game:GetService("CollectionService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)

local WeaponService = Modux.Service("WeaponService"):Import("PlayerService")

WeaponService:OnInit(function(self)
	self.Network.Packages.GetWeapon:handle(function(_, Player: Player?)
		if not Player then
			return nil
		end

		local playerEquipment = self:GetComponent(Player, "EquipmentComponent")
		if not playerEquipment then
			return nil
		end

		local ammo = { 0, 0, 0 }
		for slot, amount in playerEquipment.SlotAmmo do
			ammo[slot] = amount
		end

		return {
			WeaponID = playerEquipment.WeaponID,
			Ammo = ammo,
			ActiveSlot = playerEquipment.ActiveSlot,
		}
	end)

	self.Network.Packages.SwitchSlot:on(function(request: { Slot: number }, Player: Player?)
		if not Player then
			return
		end

		local playerEquipment = self:GetComponent(Player, "EquipmentComponent")
		if not playerEquipment then
			return
		end

		playerEquipment:SwitchSlot(request.Slot)
	end)

	self.PlayerService:OnPlayerAdded(function(Player: Player)
		CollectionService:AddTag(Player, "EquipmentComponent")
	end)
end)

WeaponService:OnStart(function(self) end)

return WeaponService
