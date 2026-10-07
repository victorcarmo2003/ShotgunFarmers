--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local PracticeCatalog = require(ReplicatedStorage.shared.Practice.PracticeCatalog)
local PracticeNet = require(ReplicatedStorage.shared.Practice.Net)
local Modux = require(ServerScriptService.server.Modux)

const WINDOW_SECONDS = 1
const WINDOW_LIMIT = 20
const RESPAWN_COOLDOWN = 1

const PracticeService = Modux.Service("PracticeService", {
	Require = { "PlayerService", "ServerRoleService", "SpawnService" },
	Priority = 600,
})

function PracticeService:Setup()
	self.Choices = {} :: { [Player]: { [number]: GetGun.GunNames } }
	self.Windows = {} :: { [Player]: { Start: number, Count: number } }
	self.LastRespawn = {} :: { [Player]: number }
end

function PracticeService:IsPractice(): boolean
	const roles = self.Dependencies.ServerRoleService
	if not roles:IsMatch() then
		return false
	end

	const config = roles:GetConfig()
	return config ~= nil and config.Mode == PracticeCatalog.MODE
end

function PracticeService:Allow(player: Player): boolean
	if not self:IsPractice() then
		return false
	end

	const now = os.clock()
	local window = self.Windows[player]
	if not window or now - window.Start >= WINDOW_SECONDS then
		window = { Start = now, Count = 0 }
		self.Windows[player] = window
	end

	window.Count += 1
	return window.Count <= WINDOW_LIMIT
end

function PracticeService:Equip(player: Player, gunID: number): boolean
	const entry = PracticeCatalog.ByID[gunID]
	if not entry then
		return false
	end
	const gunName = entry.Name

	const equipment = self.Components.Equipment:Get(player)
	if not equipment then
		return false
	end

	const slot = equipment:SlotFor(gunName)
	if slot ~= entry.Slot then
		return false
	end

	if not equipment:SetSlot(gunName, true) then
		return false
	end

	local choices = self.Choices[player]
	if not choices then
		choices = {}
		self.Choices[player] = choices
	end
	choices[entry.Slot] = gunName

	return true
end

function PracticeService:SetInfinite(player: Player, ammo: boolean, grenades: boolean)
	player:SetAttribute(PracticeCatalog.INFINITE_AMMO, if ammo then true else nil)
	player:SetAttribute(PracticeCatalog.INFINITE_GRENADES, if grenades then true else nil)

	const equipment = self.Components.Equipment:Get(player)
	if equipment then
		equipment:Refill()
	end
end

function PracticeService:Refill(player: Player)
	const equipment = self.Components.Equipment:Get(player)
	if equipment then
		equipment:Refill()
	end
end

function PracticeService:Respawn(player: Player)
	const now = os.clock()
	const last = self.LastRespawn[player]
	if last and now - last < RESPAWN_COOLDOWN then
		return
	end

	self.LastRespawn[player] = now
	self.Dependencies.SpawnService:Respawn(player, 0)
end

function PracticeService:Reapply(player: Player)
	const choices = self.Choices[player]
	const equipment = self.Components.Equipment:Get(player)
	if not choices or not equipment then
		return
	end

	const activeSlot = equipment.ActiveSlot
	for slot, gunName in choices do
		if equipment.Loadout[slot] ~= gunName then
			equipment:SetSlot(gunName, false)
		end
	end

	if equipment.ActiveSlot ~= activeSlot and equipment.Loadout[activeSlot] then
		equipment:SwitchSlot(activeSlot)
	end
end

function PracticeService:Forget(player: Player)
	self.Choices[player] = nil
	self.Windows[player] = nil
	self.LastRespawn[player] = nil
end

PracticeService:OnStart(function(self)
	const roleService = self.Dependencies.ServerRoleService
	roleService:OnReady(function()
		if not self:IsPractice() then
			return
		end

		for _, player in Players:GetPlayers() do
			self:SetInfinite(player, true, true)
		end
		self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
			self:SetInfinite(player, true, true)
		end)
	end)
end)

PracticeService:OnInit(function(self)
	self:Setup()

	PracticeNet.Equip:onServer(function(request, player)
		if self:Allow(player) then
			self:Equip(player, request.Gun)
		end
	end)

	PracticeNet.SetInfinite:onServer(function(request, player)
		if self:Allow(player) then
			self:SetInfinite(player, request.Ammo, request.Grenades)
		end
	end)

	PracticeNet.Refill:onServer(function(_, player)
		if self:Allow(player) then
			self:Refill(player)
		end
	end)

	PracticeNet.Respawn:onServer(function(_, player)
		if self:Allow(player) then
			self:Respawn(player)
		end
	end)

	self.Dependencies.PlayerService.CharacterAdded:Connect(function(player)
		if not self.Choices[player] then
			return
		end

		task.defer(function()
			self:Reapply(player)
		end)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Forget(player)
	end)
end)

return PracticeService
