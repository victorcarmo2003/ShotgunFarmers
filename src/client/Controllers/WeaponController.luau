local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local GetGun = require(ReplicatedStorage.Shared.Utils.GetGun)

local WeaponController = Modux.Controller("WeaponController"):Import("InputController")
type Self = typeof(WeaponController)

local SLOT_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }

WeaponController.GetScopes = function(self: Self): Fusion.Scope
	return self.Scope
end

WeaponController.UpdateWeaponID = function(self: Self, weaponID: number)
	self.WeaponID:set(weaponID)
end

WeaponController.UpdateSlotAmmo = function(self: Self, slot: number, ammo: number)
	local ammoValue = self.SlotAmmo[slot]
	if ammoValue then
		ammoValue:set(ammo)
	end
end

WeaponController.UpdateActiveSlot = function(self: Self, slot: number)
	self.ActiveSlot:set(slot)
end

WeaponController.SwitchSlot = function(self: Self, slot: number)
	self.Network.Packages.SwitchSlot:send({ Slot = slot })
end

WeaponController:OnInit(function(self)
	local scoped = Fusion.scoped(Fusion)
	self.Scope = scoped
	self.WeaponID = scoped:Value(0)
	self.ActiveSlot = scoped:Value(1)
	self.SlotAmmo = { scoped:Value(0), scoped:Value(0), scoped:Value(0) }
	self.DrawEndsAt = 0 :: number
	self.IsDrawingValue = scoped:Value(false) :: Fusion.Value<boolean>

	self.GunData = scoped:Computed(function(use) -- modux ignore line
		return GetGun:GetByID(use(self.WeaponID))
	end) :: Fusion.Computed<GetGun.GunData?>

	self.Ammo = scoped:Computed(function(use) -- modux ignore line
		return use(self.SlotAmmo[use(self.ActiveSlot)])
	end)

	self.Network.Packages.WeaponKey:onKey(function(key, value, _sender, timestamp) -- modux ignore line
		if key == "WeaponID" then
			self:UpdateWeaponID(value)
		elseif key == "Ammo" then
			self:UpdateSlotAmmo(value.Slot, value.Amount)
		elseif key == "ActiveSlot" then
			self:UpdateActiveSlot(value)
		elseif key == "DrawLock" then
			local endsAt = (timestamp or workspace:GetServerTimeNow()) + value
			self.DrawEndsAt = endsAt
			self.IsDrawingValue:set(true)
			task.delay(value, function()
				if self.DrawEndsAt == endsAt then
					self.IsDrawingValue:set(false)
				end
			end)
		end
	end)
end)

WeaponController:OnStart(function(self)
	task.spawn(function()
		local Weapon = self.Network.Packages.GetWeapon:request()
		if Weapon then
			self:UpdateWeaponID(Weapon.WeaponID)
			for slot, ammo in Weapon.Ammo do
				self:UpdateSlotAmmo(slot, ammo)
			end
			self:UpdateActiveSlot(Weapon.ActiveSlot)
		end
	end)

	for slot, keyCode in SLOT_KEYS do
		local handler = self.InputController:BindAction(`SwitchSlot{slot}`, keyCode)
		handler.OnPress(function()
			self:SwitchSlot(slot)
		end)
	end
end)

return WeaponController
