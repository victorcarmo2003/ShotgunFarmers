--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WeaponNet = require(ReplicatedStorage.shared.Weapon.Net)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Loadout = WeaponNet.Loadout

const SLOT_COUNT = 3

const SLOT_KEYS: { Enum.KeyCode } = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }

const WeaponController = Modux.Controller("WeaponController", {
	Require = { "InputController" },
	Priority = 750,
})

function WeaponController:Setup()
	self.Slots = Vide.source({ 0, 0, 0 }) :: Vide.Source<{ number }>
	self.ActiveSlot = Vide.source(1) :: Vide.Source<number>
	self.Ammo = Vide.source({ 0, 0, 0 }) :: Vide.Source<{ number }>

	self.DrawEndsAt = Vide.source(0) :: Vide.Source<number>

	self.DrawEnded = self.Libs.Signal.new() :: SignalLib.Signal<number>

	self.DrawGeneration = 0 :: number
end

function WeaponController:WeaponID(): number
	return self.Slots()[self.ActiveSlot()] or 0
end

function WeaponController:GunData(): GetGun.GunData?
	return GetGun.ByID(self:WeaponID())
end

function WeaponController:SlotGun(slot: number): GetGun.GunData?
	const id = self.Slots()[slot]
	return if id and id > 0 then GetGun.ByID(id) else nil
end

function WeaponController:ActiveAmmo(): number
	return self.Ammo()[self.ActiveSlot()] or 0
end

function WeaponController:IsDrawing(): boolean
	return workspace:GetServerTimeNow() < self.DrawEndsAt()
end

function WeaponController:WatchDraw(endsAt: number)
	self.DrawEndsAt(endsAt)

	self.DrawGeneration += 1
	const generation = self.DrawGeneration
	const remaining = endsAt - workspace:GetServerTimeNow()
	if remaining <= 0 then
		return
	end

	const weaponID = self:WeaponID()
	task.delay(remaining, function()
		if self.DrawGeneration == generation then
			self.DrawEnded:Fire(weaponID)
		end
	end)
end

function WeaponController:Apply(loadout: Loadout)
	self.Slots(loadout.Slots)
	self.ActiveSlot(loadout.ActiveSlot)
	self.Ammo(loadout.Ammo)
	self:WatchDraw(loadout.DrawEndsAt)
end

function WeaponController:SwitchSlot(slot: number)
	if slot < 1 or slot > SLOT_COUNT then
		return
	end

	if slot == self.ActiveSlot() then
		return
	end

	self.Libs.Net.Weapon.SwitchSlot:fireServer({ Slot = slot })
end

function WeaponController:BindKeys()
	for slot, keyCode in SLOT_KEYS do
		self.Dependencies.InputController
			:Bind({ Name = `SwitchSlot{slot}`, Key = keyCode, Priority = 10 })
			.OnPress(function()
				self:SwitchSlot(slot)
			end)
	end
end

WeaponController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Weapon.Loadout:onClient(function(loadout)
		self:Apply(loadout)
	end)
end)

WeaponController:OnStart(function(self)
	self:BindKeys()
end)

return WeaponController
