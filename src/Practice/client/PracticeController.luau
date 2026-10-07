--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local PracticeCatalog = require(ReplicatedStorage.shared.Practice.PracticeCatalog)
local PracticeNet = require(ReplicatedStorage.shared.Practice.Net)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local PracticeScreen = require(StarterPlayer.StarterPlayerScripts.client.Practice.PracticeScreen)

const MENU_SOURCE = "Practice"
const MODE_ATTRIBUTE = "GameMode"

const PracticeController = Modux.Controller("PracticeController", {
	Require = {
		"GameStateController",
		"InputController",
		"MenuEffectsController",
		"UnlockCameraController",
		"WeaponController",
	},
	Priority = 370,
})

function PracticeController:Setup()
	self.Opened = Vide.source(false) :: Vide.Source<boolean>
	self.InfiniteAmmo = Vide.source(false) :: Vide.Source<boolean>
	self.InfiniteGrenades = Vide.source(false) :: Vide.Source<boolean>
	self.Unmount = nil :: (() -> ())?
end

function PracticeController:IsPractice(): boolean
	return workspace:GetAttribute(MODE_ATTRIBUTE) == PracticeCatalog.MODE
		and self.Dependencies.GameStateController:IsInMatch()
end

function PracticeController:SetOpen(open: boolean)
	if self.Opened() == open then
		return
	end

	self.Opened(open)
	self.Dependencies.InputController:SetContext(if open then "Menu" else "Gameplay")
	self.Dependencies.UnlockCameraController:SetMenu(open)
	if open then
		self.Dependencies.MenuEffectsController:Open(MENU_SOURCE)
	else
		self.Dependencies.MenuEffectsController:Close(MENU_SOURCE)
	end
end

function PracticeController:Toggle()
	if self.Opened() then
		self:SetOpen(false)
		return
	end

	if not self:IsPractice() or self.Dependencies.InputController.Context == "Menu" then
		return
	end

	self:SetOpen(true)
end

function PracticeController:Refresh()
	if self.Opened() and not self:IsPractice() then
		self:SetOpen(false)
	end
end

function PracticeController:ReadInfinite()
	const player = Players.LocalPlayer
	Vide.batch(function()
		self.InfiniteAmmo(player:GetAttribute(PracticeCatalog.INFINITE_AMMO) == true)
		self.InfiniteGrenades(player:GetAttribute(PracticeCatalog.INFINITE_GRENADES) == true)
	end)
end

function PracticeController:Select(id: number)
	if PracticeCatalog.ByID[id] then
		PracticeNet.Equip:fireServer({ Gun = id })
	end
end

function PracticeController:SendInfinite(ammo: boolean, grenades: boolean)
	PracticeNet.SetInfinite:fireServer({ Ammo = ammo, Grenades = grenades })
end

function PracticeController:ToggleAmmo()
	self:SendInfinite(not self.InfiniteAmmo(), self.InfiniteGrenades())
end

function PracticeController:ToggleGrenades()
	self:SendInfinite(self.InfiniteAmmo(), not self.InfiniteGrenades())
end

function PracticeController:Refill()
	PracticeNet.Refill:fireServer()
end

function PracticeController:Respawn()
	PracticeNet.Respawn:fireServer()
end

function PracticeController:Mount()
	const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	const weapon = self.Dependencies.WeaponController

	self.Unmount = Vide.mount(function()
		return Vide.create("ScreenGui")({
			Name = "PracticeUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 19,

			PracticeScreen({
				Visible = self.Opened,
				Equipped = function()
					return weapon.Slots()
				end,
				InfiniteAmmo = self.InfiniteAmmo,
				InfiniteGrenades = self.InfiniteGrenades,
				OnSelect = function(id: number)
					self:Select(id)
				end,
				OnToggleAmmo = function()
					self:ToggleAmmo()
				end,
				OnToggleGrenades = function()
					self:ToggleGrenades()
				end,
				OnRefill = function()
					self:Refill()
				end,
				OnRespawn = function()
					self:Respawn()
				end,
				OnClose = function()
					self:SetOpen(false)
				end,
			}),
		})
	end, playerGui)
end

PracticeController:OnInit(function(self)
	self:Setup()
end)

PracticeController:OnStart(function(self)
	const player = Players.LocalPlayer

	self.Dependencies.InputController
		:Bind({ Name = "Practice", Key = Enum.KeyCode.B, Priority = 10 })
		.OnPress(function()
			self:Toggle()
		end)

	self:ReadInfinite()
	player:GetAttributeChangedSignal(PracticeCatalog.INFINITE_AMMO):Connect(function()
		self:ReadInfinite()
	end)
	player:GetAttributeChangedSignal(PracticeCatalog.INFINITE_GRENADES):Connect(function()
		self:ReadInfinite()
	end)

	workspace:GetAttributeChangedSignal(MODE_ATTRIBUTE):Connect(function()
		self:Refresh()
	end)
	self.Dependencies.GameStateController.Changed:Connect(function()
		self:Refresh()
	end)

	task.spawn(function()
		self:Mount()
	end)
end)

return PracticeController
