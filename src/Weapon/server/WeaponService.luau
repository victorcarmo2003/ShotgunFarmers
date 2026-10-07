--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local Modux = require(ServerScriptService.server.Modux)

const WeaponService = Modux.Service("WeaponService", {
	Require = { "PlayerService", "NetService", "GameStateService" },
	Priority = 650,
})

function WeaponService:Reconcile(player: Player)
	const exists = self.Components.Equipment:Get(player) ~= nil
	const allowed = self.Dependencies.GameStateService:Can("Loadout")
	if allowed and not exists then
		self.Components.Equipment:Create(player)
	elseif not allowed and exists then
		self.Components.Equipment:Destroy(player)
	end
end

function WeaponService:ReconcileAll()
	for _, player in Players:GetPlayers() do
		self:Reconcile(player)
	end
end

WeaponService:OnInit(function(self)
	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
		self:Reconcile(player)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		if self.Components.Equipment:Get(player) then
			self.Components.Equipment:Destroy(player)
		end
	end)

	self.Dependencies.GameStateService:OnChanged(function()
		self:ReconcileAll()
	end)

	self.Libs.Net.Weapon.SwitchSlot:onServer(function(request, player)
		const equipment = self.Components.Equipment:Get(player)
		if not equipment then
			return
		end

		equipment:SwitchSlot(request.Slot)
	end)

	self.Libs.Net.Weapon.DiscardWeapon:onServer(function(_, player)
		const equipment = self.Components.Equipment:Get(player)
		if not equipment then
			return
		end

		const _weapon, gunName = equipment:ActiveGun()
		const gunData = gunName and GetGun.ByName(gunName)
		if not gunData or not gunData.DiscardWhenEmpty then
			return
		end

		if equipment:ActiveAmmo() > 0 then
			return
		end

		equipment:DiscardActive()
	end)

	self.Dependencies.NetService.ClientReady:Connect(function(player)
		const equipment = self.Components.Equipment:Get(player)
		if equipment then
			equipment:Publish()
		end
	end)
end)

return WeaponService
