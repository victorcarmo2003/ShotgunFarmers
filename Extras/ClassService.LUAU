--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modux = require(ReplicatedStorage.Shared.Modux)
local Types = require(ReplicatedStorage.Shared.Modux.Types)

export type ClassStats = {
	MaxHealth: number?,
	MaxStamina: number?,
	WalkSpeed: number?, -- walkspeed base
	LifeRegen: number?, -- passive regeneration
	StaminaConsume: number?, -- -% reduces stamina consume
	Armor: number?, --% reduces damage intake
	Heal: number?, -- % increase heal bonus from all sources
	DamageBonus: number? -- % that increases the damage bonus
}

export type ClassDefinition<T> = {
	Id: number,
	Name: string,
	DisplayName: string,
	Description: string,
	Stats: T,
	Apply: ((player: Player, character: Model, definition: ClassDefinition<T>) -> ())?,
	Remove: ((player: Player, character: Model, definition: ClassDefinition<T>) -> ())?,
}

type AnyClassDefinition = ClassDefinition<any>
type HumanoidDefaults = {
	MaxHealth: number,
	WalkSpeed: number,
	JumpPower: number,
	JumpHeight: number,
}

local ClassService = Modux.Service("ClassService")
ClassService:Import("PlayerService")
ClassService:Import("ProfileService")

ClassService.Classes = {} :: { [number]: AnyClassDefinition }
ClassService.ClassesByName = {} :: { [string]: AnyClassDefinition }
ClassService._humanoidDefaults = setmetatable({}, { __mode = "k" }) :: { [Humanoid]: HumanoidDefaults }
ClassService.OnClassUnlocked = ClassService.Signal.new() :: Types.Signal<Player, AnyClassDefinition>
ClassService.OnClassLocked = ClassService.Signal.new() :: Types.Signal<Player, AnyClassDefinition>
ClassService.OnClassEquipped = ClassService.Signal.new() :: Types.Signal<Player, AnyClassDefinition>
ClassService.OnClassUnequipped = ClassService.Signal.new() :: Types.Signal<Player, AnyClassDefinition>

local function getHumanoid(character: Model): Humanoid?
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		return humanoid
	end
	return nil
end

local function saveHumanoidDefaults(humanoid: Humanoid)
	if ClassService._humanoidDefaults[humanoid] then
		return
	end
	ClassService._humanoidDefaults[humanoid] = {
		MaxHealth = humanoid.MaxHealth,
		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
	}
end

local function restoreHumanoidDefaults(humanoid: Humanoid)
	local defaults = ClassService._humanoidDefaults[humanoid]
	if not defaults then
		return
	end
	local healthRatio = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
	humanoid.MaxHealth = defaults.MaxHealth
	humanoid.Health = defaults.MaxHealth * healthRatio
	humanoid.WalkSpeed = defaults.WalkSpeed
	humanoid.JumpPower = defaults.JumpPower
	humanoid.JumpHeight = defaults.JumpHeight
end

local function applyHumanoidStats(player: Player, character: Model, definition: ClassDefinition<ClassStats>)
	local humanoid = getHumanoid(character)
	if not humanoid then
		return
	end
	saveHumanoidDefaults(humanoid)
	restoreHumanoidDefaults(humanoid)
	local stats = definition.Stats
	if stats.MaxHealth then
		local healthRatio = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
		humanoid.MaxHealth = stats.MaxHealth
		humanoid.Health = stats.MaxHealth * healthRatio
	end
	if stats.WalkSpeed then
		humanoid.WalkSpeed = stats.WalkSpeed
	end
	if stats.JumpPower then
		humanoid.JumpPower = stats.JumpPower
	end
	if stats.JumpHeight then
		humanoid.JumpHeight = stats.JumpHeight
	end
end

ClassService.Register = function(self, definition: AnyClassDefinition): AnyClassDefinition
	assert(type(definition.Id) == "number" and definition.Id > 0, "[ClassService] Invalid class id.")
	assert(type(definition.Name) == "string" and definition.Name ~= "", "[ClassService] Invalid class name.")
	assert(not self.Classes[definition.Id], `[ClassService] Class id already registered: {definition.Id}.`)
	assert(not self.ClassesByName[definition.Name], `[ClassService] Class name already registered: {definition.Name}.`)
	self.Classes[definition.Id] = definition
	self.ClassesByName[definition.Name] = definition
	return definition
end

ClassService.Get = function(self, identifier: number | string): AnyClassDefinition?
	if type(identifier) == "number" then
		return self.Classes[identifier]
	end
	return self.ClassesByName[identifier]
end

ClassService.GetAll = function(self): { AnyClassDefinition }
	local classes = {}
	for _, definition in self.Classes do
		table.insert(classes, definition)
	end
	table.sort(classes, function(a, b)
		return a.Id < b.Id
	end)
	return classes
end

ClassService.IsUnlocked = function(self, player: Player, identifier: number | string): boolean
	local definition = self:Get(identifier)
	if not definition then
		return false
	end
	local data = self.ProfileService:GetData(player)
	return data ~= nil and data.UnlockedClasses[definition.Id] == true
end

ClassService.Unlock = function(self, player: Player, identifier: number | string): boolean
	local definition = self:Get(identifier)
	assert(definition, `[ClassService] Class not registered: {identifier}.`)
	local data = self.ProfileService:GetData(player)
	if not data or data.UnlockedClasses[definition.Id] then
		return false
	end
	data.UnlockedClasses[definition.Id] = true
	self.ProfileService:ReplicateKey(player, "UnlockedClasses")
	self.OnClassUnlocked:Fire(player, definition)
	return true
end

ClassService.Lock = function(self, player: Player, identifier: number | string): boolean
	local definition = self:Get(identifier)
	assert(definition, `[ClassService] Class not registered: {identifier}.`)
	local data = self.ProfileService:GetData(player)
	if not data or not data.UnlockedClasses[definition.Id] then
		return false
	end
	if data.CurrentClass == definition.Name then
		self:Unequip(player)
	end
	data.UnlockedClasses[definition.Id] = nil
	self.ProfileService:ReplicateKey(player, "UnlockedClasses")
	self.OnClassLocked:Fire(player, definition)
	return true
end

ClassService.GetEquipped = function(self, player: Player): AnyClassDefinition?
	local data = self.ProfileService:GetData(player)
	if not data or data.CurrentClass == "" then
		return nil
	end
	return self:Get(data.CurrentClass)
end

ClassService.Apply = function(self, player: Player, character: Model?): boolean
	local targetCharacter = character or player.Character
	if not targetCharacter then
		return false
	end
	local equipped = self:GetEquipped(player)
	if not equipped then
		local humanoid = getHumanoid(targetCharacter)
		if humanoid then
			restoreHumanoidDefaults(humanoid)
		end
		return false
	end
	if equipped.Apply then
		equipped.Apply(player, targetCharacter, equipped)
	end
	return true
end

ClassService.Equip = function(self, player: Player, identifier: number | string): boolean
	local definition = self:Get(identifier)
	assert(definition, `[ClassService] Class not registered: {identifier}.`)
	if not self:IsUnlocked(player, definition.Id) then
		return false
	end
	local data = self.ProfileService:GetData(player)
	if not data then
		return false
	end
	local previous = self:Get(data.CurrentClass)
	if previous and previous.Remove and player.Character then
		previous.Remove(player, player.Character, previous)
	end
	data.CurrentClass = definition.Name
	self.ProfileService:ReplicateKey(player, "CurrentClass")
	self:Apply(player)
	self.OnClassEquipped:Fire(player, definition)
	return true
end

ClassService.Unequip = function(self, player: Player): boolean
	local data = self.ProfileService:GetData(player)
	if not data or data.CurrentClass == "" then
		return false
	end
	local previous = self:Get(data.CurrentClass)
	if previous and previous.Remove and player.Character then
		previous.Remove(player, player.Character, previous)
	end
	data.CurrentClass = ""
	self.ProfileService:ReplicateKey(player, "CurrentClass")
	self:Apply(player)
	if previous then
		self.OnClassUnequipped:Fire(player, previous)
	end
	return true
end

ClassService:OnInit(function(self)
	local tank: ClassDefinition<ClassStats> = {
		Id = 1,
		Name = "Tank",
		DisplayName = "Tank",
		Description = "High durability with reduced mobility.",
		Stats = {
			MaxHealth = 175,
			WalkSpeed = 13,
		},
		Apply = applyHumanoidStats,
	}
	local medic: ClassDefinition<ClassStats> = {
		Id = 2,
		Name = "Medic",
		DisplayName = "Medic",
		Description = "Balanced mobility prepared for support abilities.",
		Stats = {
			MaxHealth = 110,
			WalkSpeed = 17,
		},
		Apply = applyHumanoidStats,
	}
	self:Register(tank)
	self:Register(medic)
	self.PlayerService:OnCharacterAdded(function(character: Model, player: Player)
		self:Apply(player, character)
	end)
end)

return ClassService
