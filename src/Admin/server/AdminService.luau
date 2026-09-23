--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AdminSettings = require(ReplicatedStorage.shared.Admin.AdminSettings)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local Template = require(ServerScriptService.server.Profile.ProfileService.Template)
local conch = require(ReplicatedStorage.Packages.Conch)
local Modux = require(ServerScriptService.server.Modux)

const DEFAULT_AMMO = 30
const DEFAULT_KILL_REASON = "admin reasons."

const AdminService = Modux.Service("AdminService", {
	Require = { "PlayerService", "ProfileService" },
	Priority = 640,
})

local function gunNames(): { string }
	const names = {}
	for name in GetGun.All do
		table.insert(names, name)
	end

	return names
end

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

function AdminService:Register()
	conch.register("give", {
		permissions = { "admin" },
		description = "Da arma ou municao para um jogador",
		arguments = function()
			return conch.args.overload({
				{
					conch.args.literal("gun"),
					conch.args.player("player"),
					conch.args.enum_from_array("gun_name", gunNames())("gun_name"),
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
