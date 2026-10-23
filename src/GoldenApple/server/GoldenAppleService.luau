--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GoldenAppleSettings = require(ReplicatedStorage.shared.GoldenApple.GoldenAppleSettings)
local WeaponSounds = require(ReplicatedStorage.shared.Weapon.WeaponSounds)
local GunRules = require(ServerScriptService.server.Weapon.GunRules)
local Modux = require(ServerScriptService.server.Modux)

const TICK_RATE = 1

const GoldenAppleService = Modux.Service("GoldenAppleService", {
	Require = { "WeaponSpawnService" },
	Priority = 280,
})

function GoldenAppleService:Setup()
	self.Enabled = false :: boolean
	self.Apples = {} :: { BasePart }
	self.NextAt = 0 :: number
end

function GoldenAppleService:Eat(player: Player): boolean
	const vital = self.Components.Vital:Get(player)
	if not vital or not vital.Alive or vital.Health >= GoldenAppleSettings.MAX_HEALTH then
		return false
	end

	vital:Heal(GoldenAppleSettings.HEAL_AMOUNT)

	const character = player.Character
	const head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	if head then
		WeaponSounds.PlayPooled(GoldenAppleSettings.BITE_SOUND, head)
	end
	return true
end

function GoldenAppleService:SpawnAt(point: Vector3): BasePart?
	const seed = GunRules.PlantAt(point, GoldenAppleSettings.ASSET_NAME, "GoldenApple")
	if seed then
		table.insert(self.Apples, seed)
	end
	return seed
end

function GoldenAppleService:SpawnOne(): boolean
	const point = self.Dependencies.WeaponSpawnService:RandomPoint(self.Apples, GoldenAppleSettings.MIN_SEPARATION)
	return point ~= nil and self:SpawnAt(point) ~= nil
end

function GoldenAppleService:Prune()
	for index = #self.Apples, 1, -1 do
		if not self.Apples[index].Parent then
			table.remove(self.Apples, index)
		end
	end
end

function GoldenAppleService:Clear()
	for _, apple in self.Apples do
		if apple.Parent then
			apple:Destroy()
		end
	end
	table.clear(self.Apples)
end

function GoldenAppleService:Step()
	const active = self.Dependencies.WeaponSpawnService:IsActive()
	if active ~= self.Enabled then
		self.Enabled = active
		if active then
			self.NextAt = os.clock() + GoldenAppleSettings.FIRST_SPAWN_DELAY
		else
			self:Clear()
		end
	end

	if not active then
		return
	end

	self:Prune()
	const now = os.clock()
	if #self.Apples >= GoldenAppleSettings.MAX_ACTIVE or now < self.NextAt then
		return
	end

	if self:SpawnOne() then
		self.NextAt = now + GoldenAppleSettings.SPAWN_INTERVAL
	end
end

GoldenAppleService:OnInit(function(self)
	self:Setup()
end)

GoldenAppleService:OnTick(function(self)
	self:Step()
end, TICK_RATE)

return GoldenAppleService
