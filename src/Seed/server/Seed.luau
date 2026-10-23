--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local GoldenAppleSettings = require(ReplicatedStorage.shared.GoldenApple.GoldenAppleSettings)
local SeedSettings = require(ReplicatedStorage.shared.Seed.SeedSettings)
local Modux = require(ServerScriptService.server.Modux)

const HOLD_DURATION = 0.5
const TICK_RATE = 10

const Seed = Modux.Component("Seed", { Tag = "Seed", Require = { "GoldenAppleService", "PlantLoopService" } })

function Seed:Setup()
	const attribute = self.Instance:GetAttribute("GunName")
	const plantedAt = self.Instance:GetAttribute("PlantedAt")
	const source = self.Instance:GetAttribute(SeedSettings.SOURCE_ATTRIBUTE)
	const plantedBy = self.Instance:GetAttribute(SeedSettings.PLANTED_BY_ATTRIBUTE)
	const gunName = if type(attribute) == "string" then attribute else ""

	self.GunName = gunName :: string
	self.GunData = GetGun.ByName(gunName) :: GetGun.GunData?
	self.Consumable = (gunName == GoldenAppleSettings.ASSET_NAME) :: boolean
	self.PlantedAt = (if type(plantedAt) == "number" then plantedAt else workspace:GetServerTimeNow()) :: number
	self.Source = (if type(source) == "string" then source else "Unknown") :: string
	self.PlanterId = (if type(plantedBy) == "number" then plantedBy else 0) :: number

	self.Prompt = nil :: ProximityPrompt?
	self.Trigger = nil :: RBXScriptConnection?
	self.Harvested = false :: boolean
end

function Seed:Collect(player: Player): (boolean, boolean)
	if self.Consumable then
		return self.Dependencies.GoldenAppleService:Eat(player), false
	end

	const equipment = self.Components.Equipment:Get(player)
	if not equipment then
		return false, false
	end

	if equipment:HasGun(self.GunName) then
		const gunData = self.GunData
		const amount = if gunData and gunData.PoseKind == "Throwable"
			then gunData.Amount
			else SeedSettings.AMMO_REWARD_AMOUNT
		equipment:AddAmmo(self.GunName, amount)
		return true, false
	end

	return equipment:Grant(self.GunName :: GetGun.GunNames), true
end

function Seed:Report(event: "Planted" | "Harvestable" | "Expired")
	if self.Consumable then
		return
	end

	const loop = self.Dependencies.PlantLoopService
	if event == "Planted" then
		loop:Planted(self.GunName, self.Source, self.PlanterId)
	elseif event == "Harvestable" then
		loop:Harvestable(self.GunName, self.Source, self.PlanterId)
	else
		loop:Expired(self.GunName, self.Source, self.PlanterId)
	end
end

function Seed:Build(actionText: string, objectText: string)
	const prompt = Instance.new("ProximityPrompt")
	prompt.RequiresLineOfSight = false
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = HOLD_DURATION
	prompt.Enabled = false
	prompt.Parent = self.Instance
	self.Prompt = prompt

	self.Trigger = prompt.Triggered:Connect(function(player: Player)
		if self.Harvested then
			return
		end

		const collected, granted = self:Collect(player)
		if not collected then
			return
		end

		self.Harvested = true
		if not self.Consumable then
			self.Dependencies.PlantLoopService:Harvested(player, self.GunName, self.Source, self.PlanterId, granted)
		end
		self.Instance:Destroy()
	end)
end

Seed:OnInit(function(self)
	self:Setup()

	if self.Consumable then
		self:Build(GoldenAppleSettings.ACTION_TEXT, GoldenAppleSettings.OBJECT_TEXT)
		return
	end

	const gunData = self.GunData
	if not gunData then
		warn(`[Seed] GunName invalido ou ausente ("{self.GunName}"); plantada fora de GunRules.PlantAt?`)
		self.Instance:Destroy()
		return
	end

	self:Build("COLLECT", gunData.DisplayName)
	self:Report("Planted")
end)

Seed:OnTick(function(self)
	if self.Harvested then
		return
	end

	const age = workspace:GetServerTimeNow() - self.PlantedAt
	if age >= SeedSettings.SEED_LIFETIME then
		self.Harvested = true
		self:Report("Expired")
		self.Instance:Destroy()
		return
	end

	const prompt = self.Prompt
	if prompt and not prompt.Enabled and age >= SeedSettings.COLLECT_TIME_THRESHOLD then
		prompt.Enabled = true
		self:Report("Harvestable")
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
