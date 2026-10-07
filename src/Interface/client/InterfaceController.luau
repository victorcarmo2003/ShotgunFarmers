--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
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
const BLOOM_PER_SHOT = 0.35
const BLOOM_RECOVERY = 2.5
const MOVEMENT_SPRING = 0.12

const InterfaceController = Modux.Controller("InterfaceController", {
	Require = {
		"ArmsController",
		"GameStateController",
		"HitController",
		"KillFeedController",
		"MovementController",
		"OptionsController",
		"RoundController",
		"SurfaceUIController",
		"VitalController",
		"WeaponController",
	},
	Priority = 200,
})

function InterfaceController:Setup()
	self.PlayerImage = Vide.source("") :: Vide.Source<string>
	self.Bloom = Vide.source(0) :: Vide.Source<number>
	self.Unmount = nil :: (() -> ())?
end

local function surface(parent: Instance, name: string, adornee: Part, enabled: () -> boolean, child: Instance): SurfaceGui
	return create("SurfaceGui")({
		Name = name,
		Adornee = adornee,
		AlwaysOnTop = true,
		Face = Enum.NormalId.Back,
		PixelsPerStud = PIXELS_PER_STUD,
		ResetOnSpawn = false,
		Enabled = enabled,
		Parent = parent,

		child,
	})
end

function InterfaceController:AddBloom()
	self.Bloom(math.min(self.Bloom() + BLOOM_PER_SHOT, 1))
end

function InterfaceController:StepBloom(deltaTime: number)
	const current = self.Bloom()
	if current > 0 then
		self.Bloom(math.max(current - BLOOM_RECOVERY * deltaTime, 0))
	end
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
	const movement = self.Dependencies.MovementController
	const options = self.Dependencies.OptionsController
	const hud = self.Dependencies.GameStateController:Capability("Hud")

	self.Unmount = Vide.mount(function()
		surface(
			playerGui,
			"MainUI",
			panels.MainUI,
			hud,
			TimerLabel({
				Text = function()
					return round:Label()
				end,
			})
		)

		surface(
			playerGui,
			"KillFeedUI",
			panels.MainUI,
			hud,
			KillFeed({
				Entries = killFeed.Entries,
			})
		)

		surface(
			playerGui,
			"PlayerStatusUI",
			panels.PlayerStatusUI,
			hud,
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
					return self.PlayerImage()
				end,
			})
		)

		surface(playerGui, "GunUI", panels.GunUI, hud, GunBar({ Slots = self:BuildGunSlots() }))

		return create("ScreenGui")({
			Name = "CrosshairUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			Enabled = hud,

			Crosshair.new({
				Config = function()
					return options:CrosshairConfig()
				end,
				Movement = Vide.spring(function()
					return if movement.IsMoving() then 1 else 0
				end, MOVEMENT_SPRING, 1),
				Firing = self.Bloom,
				Visible = function()
					return not arms.IsAiming()
				end,
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
	self.Dependencies.HitController.Fired:Connect(function()
		self:AddBloom()
	end)

	RunService.RenderStepped:Connect(function(deltaTime: number)
		self:StepBloom(deltaTime)
	end)

	const surfaces = self.Dependencies.SurfaceUIController

	const main = surfaces:New("MainUI", { Depth = 2.7 })
	const status = surfaces:New("PlayerStatusUI", { Rotation = Vector3.new(0, 10, 0), Depth = 3.9 })
	const guns = surfaces:New("GunUI", { Rotation = Vector3.new(0, -10, 0), Depth = 3.9 })
	if not main or not status or not guns then
		warn("[InterfaceController] painel nao criado; HUD nao sobe")
		return
	end

	self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"), {
		MainUI = main,
		PlayerStatusUI = status,
		GunUI = guns,
	})

	task.spawn(function()
		const image = GetThumbnail.HeadShot(Players.LocalPlayer)
		self.PlayerImage(image or "")
	end)
end)

return InterfaceController
