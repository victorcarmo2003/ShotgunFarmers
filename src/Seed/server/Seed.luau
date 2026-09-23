--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local SeedSettings = require(ReplicatedStorage.shared.Seed.SeedSettings)
local Modux = require(ServerScriptService.server.Modux)

const HOLD_DURATION = 0.5
const TICK_RATE = 10

const Seed = Modux.Component("Seed", { Tag = "Seed" })

function Seed:Setup()
	const attribute = self.Instance:GetAttribute("GunName")
	const plantedAt = self.Instance:GetAttribute("PlantedAt")
	const gunName = if type(attribute) == "string" then attribute else ""

	self.GunName = gunName :: string
	self.GunData = GetGun.ByName(gunName) :: GetGun.GunData?
	self.PlantedAt = (if type(plantedAt) == "number" then plantedAt else workspace:GetServerTimeNow()) :: number

	self.Prompt = nil :: ProximityPrompt?
	self.Trigger = nil :: RBXScriptConnection?
	self.Harvested = false :: boolean
end

function Seed:Collect(player: Player): boolean
	const equipment = self.Components.Equipment:Get(player)
	if not equipment then
		return false
	end

	if equipment:HasGun(self.GunName) then
		equipment:AddAmmo(self.GunName, SeedSettings.AMMO_REWARD_AMOUNT)
		return true
	end

	return equipment:Grant(self.GunName :: GetGun.GunNames)
end

function Seed:Build(gunData: GetGun.GunData)
	const prompt = Instance.new("ProximityPrompt")
	prompt.RequiresLineOfSight = false
	prompt.ActionText = "COLLECT"
	prompt.ObjectText = gunData.DisplayName
	prompt.HoldDuration = HOLD_DURATION
	prompt.Enabled = false
	prompt.Parent = self.Instance
	self.Prompt = prompt

	self.Trigger = prompt.Triggered:Connect(function(player: Player)
		if self.Harvested then
			return
		end

		if not self:Collect(player) then
			return
		end

		self.Harvested = true
		self.Instance:Destroy()
	end)
end

Seed:OnInit(function(self)
	self:Setup()

	const gunData = self.GunData
	if not gunData then
		warn(`[Seed] GunName invalido ou ausente ("{self.GunName}"); plantada fora de GunRules.PlantAt?`)
		self.Instance:Destroy()
		return
	end

	self:Build(gunData)
end)

Seed:OnTick(function(self)
	const prompt = self.Prompt
	if not prompt or prompt.Enabled then
		return
	end

	if workspace:GetServerTimeNow() - self.PlantedAt >= SeedSettings.COLLECT_TIME_THRESHOLD then
		prompt.Enabled = true
	end
end, TICK_RATE)

Seed:OnDestroy(function(self)
	if self.Trigger then
		self.Trigger:Disconnect()
		self.Trigger = nil
	end

	if self.Prompt then
		self.Prompt:Destroy()
		self.Prompt = nil
	end
end)

return Seed
