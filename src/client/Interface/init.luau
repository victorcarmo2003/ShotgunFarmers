local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetThumbnail = require(ReplicatedStorage.Shared.Utils.GetThumbnail)
local GetGun = require(ReplicatedStorage.Shared.Utils.GetGun)
local GameSettings = require(ReplicatedStorage.Shared.Settings.GameSettings)
local Components = require(script.Components)
local Crosshair = require(script.GameComponents.Crosshair)
local HitMarker = require(script.GameComponents.HitMarker)
local GunBar = require(script.GameComponents.GunBar)
local KillFeed = require(script.GameComponents.KillFeed)
local StatusBar = require(script.GameComponents.StatusBar)
local TimerLabel = require(script.GameComponents.TimerLabel)
local Modux = require(game.ReplicatedStorage.Shared.Modux)

export type MainGuiType = {
	TimerLabel: TextLabel,
} & ScreenGui

local InterfaceController = Modux.Controller("InterfaceController")
	:Import("VitalController")
	:Import("WeaponController")
	:Import("SurfaceUIController")
	:Import("ArmsController")
	:Import("HitController")
	:Import("KillFeedController")
	:Import("MovementController")

InterfaceController:OnInit(function(self)
	self.Scope = self.VitalController:GetScopes()
end)

InterfaceController:OnStart(function(self)
	local part1 = self.SurfaceUIController:New("MainUI", {
		Depth = 2.7,
	})
	local part2 = self.SurfaceUIController:New("PlayerStatusUI", {
		Rotation = Vector3.new(0, 10, 0),
		Depth = 3.9,
	})
	local part3 = self.SurfaceUIController:New("GunUI", {
		Rotation = Vector3.new(0, -10, 0),
		Depth = 3.9,
	})
	local Children = self.VitalController.Scope.Children
	local Values = {
		Health = self.Scope:Computed(function(use)
			return use(self.VitalController.Health) / self.VitalController.MaxHealth
		end),
		Armor = self.Scope:Computed(function(use)
			return use(self.VitalController.Armor) / self.VitalController.MaxArmor
		end),
		PlayerImage = GetThumbnail.HeadShot(self.LocalPlayer),
	}

	-- local GunNameValues = {
	-- 	Text = self.Scope:Computed(function(use)
	-- 		local gun = use(self.WeaponController.GunData)
	-- 		return gun and gun.DisplayName or "Sem arma"
	-- 	end),
	-- }

	local MainGui = Components.SurfaceGui(self.Scope, {
		Name = "MainUI",
		Adornee = part1,
		[Children] = {
			TimerLabel = TimerLabel(self.Scope),
			-- GunNameLabel = GunNameLabel(self.Scope, GunNameValues),
		},
	})

	local PlayerGui = Components.SurfaceGui(self.Scope, {
		Name = "PlayerStatusUI",
		Adornee = part2,
		[Children] = {
			StatusBar(self.Scope, Values),
		},
	})

	-- Espelha o DEFAULT_LOADOUT do EquipmentComponent (server) só pra saber qual arma
	-- mostrar em cada slot -- nome/imagem são estáticos porque o loadout é fixo; a
	-- munição em si vem ao vivo de WeaponController.SlotAmmo (uma por slot, sempre
	-- visível, independente de qual está ativo agora).
	local slot1Gun = GetGun:GetByName("Shotgun")
	local slot2Gun = GetGun:GetByName("Peavolver")

	local GunGui = Components.SurfaceGui(self.Scope, {
		Name = "GunUI",
		Adornee = part3,
		[Children] = {
			GunBar(self.Scope, {
				Slot1 = {
					SlotNumber = "1",
					Ammo = self.Scope:Computed(function(use)
						return tostring(use(self.WeaponController.SlotAmmo[1]))
					end),
					Image = (slot1Gun and slot1Gun.ImageID) or "",
					IsActive = self.Scope:Computed(function(use)
						return use(self.WeaponController.ActiveSlot) == 1
					end),
					OnSelect = function()
						self.WeaponController:SwitchSlot(1)
					end,
				},
				Slot2 = {
					SlotNumber = "2",
					Ammo = self.Scope:Computed(function(use)
						return tostring(use(self.WeaponController.SlotAmmo[2]))
					end),
					Image = (slot2Gun and slot2Gun.ImageID) or "",
					IsActive = self.Scope:Computed(function(use)
						return use(self.WeaponController.ActiveSlot) == 2
					end),
					OnSelect = function()
						self.WeaponController:SwitchSlot(2)
					end,
				},
				Slot3 = {
					SlotNumber = "3",
					Ammo = "",
					Image = "",
				},
			}),
		},
	})

	-- KillFeed usa a mesma Part da GunUI como Adornee (permitido -- várias SurfaceGuis
	-- podem adornar a mesma Part, cada uma é um canvas 2D independente por cima dela),
	-- só que num SurfaceGui próprio pra não competir por espaço/layout com o GunBar.
	local KillFeedGui = Components.SurfaceGui(self.Scope, {
		Name = "KillFeedUI",
		Adornee = part3,
		[Children] = {
			KillFeed(self.Scope, {
				Entries = self.KillFeedController.Entries,
			}),
		},
	})

	-- Crosshair fica num ScreenGui de verdade (não SurfaceGui como o resto do HUD) --
	-- precisa estar travado no centro exato do viewport, e SurfaceGui adorando uma
	-- Part introduziria paralaxe/tremor conforme a câmera se move, o que arruinaria a
	-- mira. AimType vem da arma equipada (Guns.luau); SpreadRatio combina os mesmos
	-- fatores que o HitService/GunMixin usam de verdade (GameSettings.AimSpreadMultiplier
	-- e MovingSpreadMultiplier), então o cone visual nunca diverge do cone real validado
	-- no server. Enquanto mira, a crosshair inteira some (ver Crosshair.luau) -- não faz
	-- sentido mostrar reticle olhando pela mira da arma.
	local CrosshairAimType = self.Scope:Computed(function(use)
		local gun = use(self.WeaponController.GunData)
		return gun and gun.AimType or "Default"
	end)
	local CrosshairSpreadRatio = self.Scope:Computed(function(use)
		local ratio = 1
		if use(self.MovementController.IsMovingValue) then
			ratio *= GameSettings.MovingSpreadMultiplier
		end
		if use(self.ArmsController.IsAimingValue) then
			ratio *= GameSettings.AimSpreadMultiplier
		end
		return ratio
	end)

	local CrosshairGui = Components.ScreenGui(self.Scope, {
		Name = "CrosshairUI",
		[Children] = {
			Crosshair(self.Scope, {
				AimType = CrosshairAimType,
				SpreadRatio = CrosshairSpreadRatio,
				IsAiming = self.ArmsController.IsAimingValue,
			}),
			-- Reage a self.HitController.HitMarkerTrigger (contador que só sobe a cada
			-- acerto CONFIRMADO pelo server -- ver HitService.ProcessFire/HitController.TryHit).
			HitMarker(self.Scope, {
				Trigger = self.HitController.HitMarkerTrigger,
			}),
		},
	})

	MainGui.Parent = self.LocalPlayer.PlayerGui
	PlayerGui.Parent = self.LocalPlayer.PlayerGui
	GunGui.Parent = self.LocalPlayer.PlayerGui
	KillFeedGui.Parent = self.LocalPlayer.PlayerGui
	CrosshairGui.Parent = self.LocalPlayer.PlayerGui

	self.MainGui = MainGui
	self.PlayerGui = PlayerGui
	self.GunGui = GunGui
	self.KillFeedGui = KillFeedGui
	self.CrosshairGui = CrosshairGui
end)

return InterfaceController
