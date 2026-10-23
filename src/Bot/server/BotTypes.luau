--!strict
export type Bot = {
	IsBot: true,
	Name: string,
	DisplayName: string,
	UserId: number,
	GameID: number,
	AvatarId: number,
	Alive: boolean,
	Health: number,
	Armor: number,
	Position: Vector3,
	LookAt: Vector3,
	State: string,
	MoveDir: Vector2,
	GunName: string,
	LastShot: number,
	Ping: number,
}

export type Fighter = Player | Bot

local BotTypes = {}

function BotTypes.AsBot(fighter: Fighter): Bot?
	if typeof(fighter) == "Instance" then
		return nil
	end
	return fighter :: Bot
end

function BotTypes.AsPlayer(fighter: Fighter): Player?
	if typeof(fighter) == "Instance" then
		return fighter :: Player
	end
	return nil
end

function BotTypes.Character(fighter: Fighter): Model?
	const player = BotTypes.AsPlayer(fighter)
	return if player then player.Character else nil
end

function BotTypes.Root(character: Model?): BasePart?
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

function BotTypes.Position(fighter: Fighter): Vector3?
	const bot = BotTypes.AsBot(fighter)
	if bot then
		return if bot.Alive then bot.Position else nil
	end

	const root = BotTypes.Root(BotTypes.Character(fighter))
	return if root then root.Position else nil
end

return BotTypes
