--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AdminArguments = require(ReplicatedStorage.shared.Admin.AdminArguments)
local AdminSettings = require(ReplicatedStorage.shared.Admin.AdminSettings)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local GoldenAppleSettings = require(ReplicatedStorage.shared.GoldenApple.GoldenAppleSettings)
local GunRules = require(ServerScriptService.server.Weapon.GunRules)
local Template = require(ServerScriptService.server.Profile.ProfileService.Template)
local conch = require(ReplicatedStorage.Packages.Conch)
local Modux = require(ServerScriptService.server.Modux)

const DEFAULT_AMMO = 30
const DEFAULT_KILL_REASON = "admin reasons."
const CURSOR_RANGE = 500
const GROUND_PROBE = 20

const spawnParams = RaycastParams.new()
spawnParams.FilterType = Enum.RaycastFilterType.Exclude

const AdminService = Modux.Service("AdminService", {
	Require = { "GoldenAppleService", "IDService", "PlayerService", "ProfileService", "SnapshotService" },
	Priority = 640,
})

function AdminService:CommandGive(kind: string, target: Player, value: any)
	const equipment = self.Components.Equipment:Get(target)
	if not equipment then
		conch.log("error", `{target.Name} nao tem Equipment`)
		return
	end

	if kind == "gun" then
		const name = value :: string
		if not GetGun.ByName(name) then
			conch.log("error", `arma "{name}" nao existe`)
			return
		end

		if equipment:Grant(name :: GetGun.GunNames) then
			conch.log("success", `{target.Name} recebeu {name}`)
		else
			conch.log("error", `nao foi possivel dar "{name}" para {target.Name}`)
		end

		return
	end

	const _instance, activeName = equipment:ActiveGun()
	if not activeName then
		conch.log("error", `{target.Name} nao tem arma equipada`)
		return
	end

	const amount = (value :: number?) or DEFAULT_AMMO
	equipment:AddAmmo(activeName, amount)
	conch.log("success", `{target.Name} recebeu {amount} de municao para {activeName}`)
end

function AdminService:CommandKill(target: Player, reason: string?)
	const vital = self.Components.Vital:Get(target)
	if not vital then
		conch.log("error", `{target.Name} nao tem Vital`)
		return
	end

	vital:TakeDamage(vital.Health)
	conch.log("success", `{target.Name} morto ({reason or DEFAULT_KILL_REASON})`)
end

function AdminService:CommandTakeDamage(target: Player, amount: number)
	const vital = self.Components.Vital:Get(target)
	if not vital or not vital.Alive then
		conch.log("error", `{target.Name} nao esta vivo`)
		return
	end

	if amount <= 0 then
		conch.log("error", "amount precisa ser maior que 0")
		return
	end

	vital:TakeDamage(amount)
	conch.log("success", `{target.Name} recebeu {amount} de dano ({vital.Health} vida, {vital.Armor} escudo)`)
end

function AdminService:CommandWipe(target: Player, rejoin: boolean?)
	const profiles = self.Dependencies.ProfileService
	if not profiles:Get(target) then
		conch.log("error", `{target.Name} nao tem perfil carregado`)
		return
	end

	profiles:Update(target, Template :: any)

	if rejoin then
		const session = profiles.Sessions[target]
		if session then
			session:Save()
		end
		target:Kick("Dados resetados por um admin - por favor reconecte")
	end

	conch.log("success", `dados de {target.Name} resetados{if rejoin then " (kickado para rejoin)" else ""}`)
end

function AdminService:CommandTeleport(a: Player, b: Player?)
	const context = conch.get_command_context()
	const executor = context and context.executor.player

	const target = if b then a else executor
	const destination = if b then b else a

	if not target then
		conch.log("error", "nao foi possivel determinar o executor")
		return
	end

	const targetCharacter = target.Character
	const destinationCharacter = destination.Character
	if not targetCharacter or not destinationCharacter then
		conch.log("error", "personagem nao encontrado")
		return
	end

	targetCharacter:PivotTo(destinationCharacter:GetPivot())
	conch.log("success", `{target.Name} teleportado ate {destination.Name}`)
end

local function excludeCharacters(): { Instance }
	const ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	const seeds = workspace:FindFirstChild("Seeds")
	if seeds then
		table.insert(ignore, seeds)
	end
	return ignore
end

function AdminService:CursorPoint(player: Player): Vector3?
	const character = player.Character
	const head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end

	const id = self.Dependencies.IDService:GetPlayerID(player)
	const history = self.Dependencies.SnapshotService:GetHistory(id)
	const frame = history and history[#history]
	if not frame then
		return nil
	end

	const direction = frame.LookAt - head.Position
	if direction.Magnitude < 0.01 then
		return nil
	end

	spawnParams.FilterDescendantsInstances = excludeCharacters()
	const result = workspace:Raycast(head.Position, direction.Unit * CURSOR_RANGE, spawnParams)
	return if result then result.Position else nil
end

function AdminService:PlayerPoint(player: Player): Vector3?
	const character = player.Character
	const root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end

	spawnParams.FilterDescendantsInstances = excludeCharacters()
	const result = workspace:Raycast(root.Position, Vector3.new(0, -GROUND_PROBE, 0), spawnParams)
	return if result then result.Position else root.Position
end

function AdminService:SpawnPoint(mode: string, a: any, b: any, c: any): Vector3?
	if mode == "position" then
		return Vector3.new(a :: number, b :: number, c :: number)
	end

	if mode == "player" then
		return self:PlayerPoint(a :: Player)
	end

	const context = conch.get_command_context()
	const executor = context and context.executor.player
	if not executor then
		conch.log("error", "nao foi possivel determinar o executor")
		return nil
	end
	return self:CursorPoint(executor)
end

function AdminService:CommandSpawn(seed: string, mode: string, a: any, b: any, c: any)
	const point = self:SpawnPoint(mode, a, b, c)
	if not point then
		conch.log("error", `nenhum ponto valido para "{mode}"`)
		return
	end

	const spawned = if seed == GoldenAppleSettings.ASSET_NAME
		then self.Dependencies.GoldenAppleService:SpawnAt(point)
		else GunRules.PlantAt(point, seed, "Admin")
	if not spawned then
		conch.log("error", `nao foi possivel spawnar "{seed}"`)
		return
	end

	conch.log("success", `{seed} spawnado em {math.round(point.X)}, {math.round(point.Y)}, {math.round(point.Z)}`)
end

function AdminService:Register()
	conch.register("spawn", {
		permissions = { "admin" },
		description = "Spawna uma semente ou a GoldenApple no cursor, numa posicao ou num jogador",
		arguments = function()
			return conch.args.overload({
				{
					AdminArguments.SeedName("seed"),
					conch.args.literal("at"),
					conch.args.literal("cursor"),
				} :: { any },
				{
					AdminArguments.SeedName("seed"),
					conch.args.literal("at"),
					conch.args.literal("position"),
					conch.args.number("x"),
					conch.args.number("y"),
					conch.args.number("z"),
				} :: { any },
				{
					AdminArguments.SeedName("seed"),
					conch.args.literal("at"),
					conch.args.literal("player"),
					conch.args.player("player"),
				} :: { any },
			})
		end,
		callback = function(seed: string, _at: string, mode: string, a: any, b: any, c: any)
			self:CommandSpawn(seed, mode, a, b, c)
		end,
	})

	conch.register("give", {
		permissions = { "admin" },
		description = "Da arma ou municao para um jogador",
		arguments = function()
			return conch.args.overload({
				{
					conch.args.literal("gun"),
					conch.args.player("player"),
					AdminArguments.GunName("gun_name"),
				} :: { any },
				{
					conch.args.literal("ammo"),
					conch.args.player("player"),
					conch.args.opt(conch.args.number("amount")),
				} :: { any },
			})
		end,
		callback = function(kind: string, target: Player, value: any)
			self:CommandGive(kind, target, value)
		end,
	})

	conch.register("kill", {
		permissions = { "admin" },
		description = "Mata um jogador",
		arguments = function()
			return conch.args.player("player"), conch.args.opt(conch.args.string("reason"))
		end,
		callback = function(target: Player, reason: string?)
			self:CommandKill(target, reason)
		end,
	})

	conch.register("takedamage", {
		permissions = { "admin" },
		description = "Aplica dano em um jogador",
		arguments = function()
			return conch.args.player("target"), conch.args.number("amount")
		end,
		callback = function(target: Player, amount: number)
			self:CommandTakeDamage(target, amount)
		end,
	})

	conch.register("wipe", {
		permissions = { "admin" },
		description = "Reseta os dados de um jogador",
		arguments = function()
			return conch.args.literal("data"),
				conch.args.player("player"),
				conch.args.opt(conch.args.boolean("rejoin_player"))
		end,
		callback = function(_data: string, target: Player, rejoin: boolean?)
			self:CommandWipe(target, rejoin)
		end,
	})

	conch.register("tp", {
		permissions = { "admin" },
		description = "Teleporta um jogador ate outro",
		arguments = function()
			return conch.args.overload({
				{ conch.args.player("to") } :: { any },
				{ conch.args.player("target"), conch.args.player("to") } :: { any },
			})
		end,
		callback = function(a: Player, b: Player?)
			self:CommandTeleport(a, b)
		end,
	})
end

AdminService:OnInit(function(self)
	conch.initiate_default_lifecycle()

	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player: Player)
		if table.find(AdminSettings.AdminUserIds, player.UserId) then
			conch.give_roles(conch.get_user(player), "super-user")
		end
	end)

	self:Register()
end)

return AdminService
