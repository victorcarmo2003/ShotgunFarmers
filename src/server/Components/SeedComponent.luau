local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SeedSettings = require(ReplicatedStorage.Shared.Settings.SeedSettings)
local GetGun = require(ReplicatedStorage.Shared.Utils.GetGun)
local Modux = require(game.ReplicatedStorage.Shared.Modux)

local SeedComponent = Modux.Component("SeedComponent"):Tag("SeedComponent"):ClassName("Part")

SeedComponent.Setup = function(self)
	local ProximityPrompt = Instance.new("ProximityPrompt")
	ProximityPrompt.RequiresLineOfSight = false
	ProximityPrompt.Parent = self.Instance
	ProximityPrompt.ActionText = "COLLECT"
	ProximityPrompt.ObjectText = self.GunData.DisplayName
	ProximityPrompt.HoldDuration = 0.5
	ProximityPrompt.Enabled = false
	self.Proximity = ProximityPrompt
end

SeedComponent.Harvest = function(self)
	self._harvested = false :: boolean
	self:Cleanup(self.Proximity.Triggered:Connect(function(Player: Player)
		if self._harvested then
			return
		end
		self._harvested = true

		local equipment = self:GetComponent(Player, "EquipmentComponent")
		if not equipment then
			return
		end

		if equipment:HasGun(self.GunName) then
			equipment:AddAmmo(self.GunName, SeedSettings.AMMO_REWARD_AMOUNT)
		else
			equipment:GrantWeapon(self.GunName)
		end

		self.Instance:Destroy()
	end))
end

SeedComponent:OnStart(function(self)
	local gunName = self.Instance:GetAttribute("GunName") :: string?
	local gunData = gunName and GetGun:GetByName(gunName :: any)
	
	if not gunData then
		self.Instance:Destroy()
		return
	end

	self.GunName = gunName :: string
	self.GunData = gunData :: GetGun.GunData

	self.PlantedAt = (self.Instance:GetAttribute("PlantedAt") :: number?) or workspace:GetServerTimeNow()

	self:Setup()
	self:Harvest()
end)

SeedComponent:OnTick(function(self, deltaTime: number)
	if self.Proximity.Enabled then
		return
	end

	local elapsed = workspace:GetServerTimeNow() - self.PlantedAt
	if elapsed >= SeedSettings.COLLECT_TIME_THRESHOLD then
		self.Proximity.Enabled = true
	end
end, Modux.TickRate.Hz10)

return SeedComponent
