--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local GameSettings = require(ReplicatedStorage.shared.Settings.GameSettings)
local GetThumbnail = require(ReplicatedStorage.shared.Utils.GetThumbnail)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

local Crosshair = require(StarterPlayer.StarterPlayerScripts.client.Weapon.Crosshair)
local GunBar = require(StarterPlayer.StarterPlayerScripts.client.Weapon.GunBar)
local HitMarker = require(StarterPlayer.StarterPlayerScripts.client.Hit.HitMarker)
local KillFeed = require(StarterPlayer.StarterPlayerScripts.client.KillFeed.KillFeed)
local StatusBar = require(StarterPlayer.StarterPlayerScripts.client.Vital.StatusBar)
local TimerLabel = require(StarterPlayer.StarterPlayerScripts.client.Round.TimerLabel)

const create = Vide.create

const SLOT_COUNT = 3
const MAX_HEALTH = 100
const MAX_ARMOR = 100
const PIXELS_PER_STUD = 300

const InterfaceController = Modux.Controller("InterfaceController", {
	Require = {
		"ArmsController",
		"HitController",
		"KillFeedController",
		"MovementController",
		"RoundController",
		"SurfaceUIController",
		"VitalController",
		"WeaponController",
	},
	Priority = 200,
})

function InterfaceController:Setup()
	self.PlayerImage = "" :: string
	self.Unmount = nil :: (() -> ())?
end

local function surface(name: string, adornee: Part, child: Instance): SurfaceGui
	return create("SurfaceGui")({
		Name = name,
		Adornee = adornee,
		AlwaysOnTop = true,
		PixelsPerStud = PIXELS_PER_STUD,
		ResetOnSpawn = false,

		child,
	})
end

function InterfaceController:SpreadRatio(): number
	local ratio = 1

	if self.Dependencies.MovementController.IsMoving() then
		ratio *= GameSettings.MovingSpreadMultiplier
	end

	if self.Dependencies.ArmsController.IsAiming() then
		ratio *= GameSettings.AimSpreadMultiplier
	end

	return ratio
end

function InterfaceController:BuildGunSlots(): { GunBar.SlotProps }
	const weapon = self.Dependencies.WeaponController
	const slots: { GunBar.SlotProps } = {}

	for slot = 1, SLOT_COUNT do
		table.insert(slots, {
			SlotNumber = tostring(slot),
			Ammo = function()
				return tostring(weapon.Ammo()[slot] or 0)
			end,
			IsActive = function()
				return weapon.ActiveSlot() == slot
			end,
			Image = function()
				const gunData = weapon:SlotGun(slot)
				return if gunData then gunData.ImageID else ""
			end,
			OnSelect = function()
				weapon:SwitchSlot(slot)
			end,
		})
	end

	return slots
end

function InterfaceController:Mount(playerGui: Instance, panels: { [string]: Part })
	const vital = self.Dependencies.VitalController
	const round = self.Dependencies.RoundController
	const killFeed = self.Dependencies.KillFeedController
	const hit = self.Dependencies.HitController
	const arms = self.Dependencies.ArmsController
	const weapon = self.Dependencies.WeaponController

	self.Unmount = Vide.mount(function()
		surface(
			"MainUI",
			panels.MainUI,
			TimerLabel({
				Text = function()
					return round:Label()
				end,
			})
		)

		surface(
			"KillFeedUI",
			panels.MainUI,
			KillFeed({
				Entries = killFeed.Entries,
			})
		)

		surface(
			"PlayerStatusUI",
			panels.PlayerStatusUI,
			StatusBar({
				Health = function()
					return vital.Health() / MAX_HEALTH
				end,
				Armor = function()
					return vital.Armor() / MAX_ARMOR
				end,
				PlayerName = function()
					return Players.LocalPlayer.DisplayName
				end,
				PlayerImage = function()
					return self.PlayerImage
				end,
			})
		)

		surface("GunUI", panels.GunUI, GunBar({ Slots = self:BuildGunSlots() }))

		return create("ScreenGui")({
			Name = "CrosshairUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,

			Crosshair({
				AimType = function()
					const gunData = weapon:GunData()
					return if gunData and gunData.AimType then gunData.AimType else "Default"
				end,
				SpreadRatio = function()
					return self:SpreadRatio()
				end,
				IsAiming = arms.IsAiming,
			}),

			HitMarker({
				Trigger = hit.HitMarkerTrigger,
			}),
		})
	end, playerGui)
end

InterfaceController:OnInit(function(self)
	self:Setup()
end)

InterfaceController:OnStart(function(self)
	const surfaces = self.Dependencies.SurfaceUIController

	const main = surfaces:New("MainUI", { Depth = 2.7 })
	const status = surfaces:New("PlayerStatusUI", { Rotation = Vector3.new(0, 10, 0), Depth = 3.9 })
	const guns = surfaces:New("GunUI", { Rotation = Vector3.new(0, -10, 0), Depth = 3.9 })
	if not main or not status or not guns then
		warn("[InterfaceController] painel nao criado; HUD nao sobe")
		return
	end

	const image = GetThumbnail.HeadShot(Players.LocalPlayer)
	self.PlayerImage = image or ""

	self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"), {
		MainUI = main,
		PlayerStatusUI = status,
		GunUI = guns,
	})
end)

return InterfaceController
