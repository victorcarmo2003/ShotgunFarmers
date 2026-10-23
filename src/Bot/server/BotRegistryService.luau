--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Body = require(ReplicatedStorage.shared.Hit.Body)
local BotSettings = require(ReplicatedStorage.shared.Bot.BotSettings)
local BotTypes = require(ServerScriptService.server.Bot.BotTypes)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

type Bot = BotTypes.Bot

const BotRegistryService = Modux.Service("BotRegistryService", { Require = { "IDService" }, Priority = 845 })

function BotRegistryService:Setup()
	self.Bots = {} :: { [number]: Bot }
	self.Serial = 0 :: number
	self.Added = self.Libs.Signal.new() :: SignalLib.Signal<Bot>
	self.Removing = self.Libs.Signal.new() :: SignalLib.Signal<Bot>
	self.Died = self.Libs.Signal.new() :: SignalLib.Signal<Bot>
end

function BotRegistryService:Create(displayName: string, avatarId: number): Bot
	self.Serial += 1
	const gameId = self.Dependencies.IDService:Reserve()
	const bot: Bot = {
		IsBot = true,
		Name = displayName,
		DisplayName = displayName,
		UserId = -self.Serial,
		GameID = gameId,
		AvatarId = avatarId,
		Alive = false,
		Health = 0,
		Armor = 0,
		Position = Vector3.zero,
		LookAt = Vector3.zAxis,
		State = "Dead",
		MoveDir = Vector2.zero,
		GunName = "",
		LastShot = 0,
		Ping = math.random(BotSettings.PingMin, BotSettings.PingMax),
	}
	self.Bots[gameId] = bot
	self.Added:Fire(bot)
	return bot
end

function BotRegistryService:Remove(bot: Bot)
	if self.Bots[bot.GameID] ~= bot then
		return
	end

	bot.Alive = false
	self.Removing:Fire(bot)
	self.Bots[bot.GameID] = nil
	self.Dependencies.IDService:Release(bot.GameID)
end

function BotRegistryService:FromID(id: number): Bot?
	return self.Bots[id]
end

function BotRegistryService:All(): { Bot }
	const list: { Bot } = {}
	for _, bot in self.Bots do
		table.insert(list, bot)
	end
	return list
end

function BotRegistryService:Count(): number
	local total = 0
	for _ in self.Bots do
		total += 1
	end
	return total
end

function BotRegistryService:Revive(bot: Bot, position: Vector3, lookAt: Vector3)
	bot.Health = BotSettings.MaxHealth
	bot.Armor = 0
	bot.Alive = true
	bot.Position = position
	bot.LookAt = lookAt
	bot.State = "Walking"
	bot.MoveDir = Vector2.zero
end

function BotRegistryService:Damage(bot: Bot, amount: number): (number, boolean)
	if not bot.Alive then
		return 0, false
	end

	local incoming = math.max(amount, 0)
	const dealt = math.min(incoming, bot.Health + bot.Armor)
	if bot.Armor > 0 then
		const absorbed = math.min(bot.Armor, incoming)
		bot.Armor -= absorbed
		incoming -= absorbed
	end

	bot.Health = math.max(bot.Health - incoming, 0)
	if bot.Health > 0 then
		return dealt, false
	end

	bot.Alive = false
	bot.State = "Dead"
	self.Died:Fire(bot)
	return dealt, true
end

function BotRegistryService:Heal(bot: Bot, amount: number)
	if bot.Alive then
		bot.Health = math.min(bot.Health + math.max(amount, 0), BotSettings.MaxHealth)
	end
end

local function raySphere(origin: Vector3, direction: Vector3, center: Vector3, radius: number): number?
	const offset = origin - center
	const b = offset:Dot(direction)
	const c = offset:Dot(offset) - radius * radius
	const discriminant = b * b - c
	if discriminant < 0 then
		return nil
	end

	const root = math.sqrt(discriminant)
	const near = -b - root
	if near >= 0 then
		return near
	end
	const far = -b + root
	return if far >= 0 then 0 else nil
end

function BotRegistryService:TraceBot(bot: Bot, origin: Vector3, direction: Vector3, position: Vector3?): (number?, number)
	const center = position or bot.Position
	const head = raySphere(origin, direction, center + Vector3.new(0, BotSettings.EyeHeight, 0), BotSettings.HeadRadius)
	const torso = raySphere(origin, direction, center, BotSettings.TorsoRadius)
	const legs = raySphere(origin, direction, center - Vector3.new(0, BotSettings.LegsOffset, 0), BotSettings.LegsRadius)

	local best: number? = nil
	local part = Body.Torso
	for _, candidate in { { head, Body.Head }, { torso, Body.Torso }, { legs, Body["Left Leg"] } } do
		const distance = candidate[1] :: number?
		if distance and (best == nil or distance < best) then
			best = distance
			part = candidate[2] :: number
		end
	end
	return best, part
end

function BotRegistryService:RayHit(origin: Vector3, direction: Vector3, maxDistance: number, ignore: Bot?): (Bot?, number, number)
	if direction.Magnitude < 0.001 then
		return nil, maxDistance, Body.Other
	end
	const unit = direction.Unit

	local closest: Bot? = nil
	local closestDistance = maxDistance
	local closestPart = Body.Other
	for _, bot in self.Bots do
		if bot == ignore or not bot.Alive then
			continue
		end

		const distance, part = self:TraceBot(bot, origin, unit)
		if distance and distance <= closestDistance then
			closest = bot
			closestDistance = distance
			closestPart = part
		end
	end

	return closest, closestDistance, closestPart
end

BotRegistryService:OnInit(function(self)
	self:Setup()
end)

return BotRegistryService
