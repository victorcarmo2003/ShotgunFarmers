--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local Atomic = require(ReplicatedStorage.shared.Types.Atomic)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Struct = require(ReplicatedStorage.shared.Types.Struct)
local Template = require(script.Template)
local Modux = require(ServerScriptService.server.Modux)


export type Data = typeof(Template)
export type Profile = Atomic.Table<Data>

const STORE_NAME = "Player"

const ProfileService = Modux.Service(
	"ProfileService",
	{ Require = { "PlayerService", "NetService", "ServerRoleService", "TeleportGateway" }, Priority = 800 }
)

function ProfileService:Setup()
	self.Store = ProfileStore.New(STORE_NAME, Template) :: any
	self.Sessions = {} :: { [Player]: any }
	self.Profiles = {} :: { [Player]: Profile }
	self.Disposers = {} :: { [Player]: () -> () }
	self.Loaded = self.Libs.Signal.new() :: SignalLib.Signal<Player, Profile>
	self.Enabled = false :: boolean
	self.Started = {} :: { [Player]: boolean }
end

function ProfileService:Begin(player: Player)
	if not self.Enabled or self.Started[player] or player.Parent ~= Players then
		return
	end

	self.Started[player] = true
	task.spawn(function()
		self:Load(player)
	end)
end

function ProfileService:Get(player: Player): Profile?
	return self.Profiles[player]
end

function ProfileService:Update(player: Player, patch: Struct.Partial<Data>)
	const profile = self.Profiles[player]
	if not profile then
		warn(`[ProfileService] {player.Name} has no loaded profile`)
		return
	end

	const fields: { [string]: (any) -> any } = profile :: any
	self.Libs.Charm.batch(function()
		for key, value in patch :: { [string]: any } do
			const field = fields[key]
			if field == nil then
				warn(`[ProfileService] {key} is not a profile field`)
				continue
			end
			field(value)
		end
	end)
end

function ProfileService:Replicate(player: Player)
	const profile = self.Profiles[player]
	if not profile then
		return
	end
	if not self.Dependencies.NetService:IsReady(player) then
		return
	end

	self.Libs.Net.Profile.Data:fireClient(player, {
		Gems = profile.Gems(),

		Gamepasses = profile.Gamepasses(),

		Item = profile.Item(),
		UnlockedItems = profile.UnlockedItems(),
		UnlockedClasses = profile.UnlockedClasses(),
		Badgets = profile.Badgets(),

		FirstLogin = profile.FirstLogin(),

		Wins = profile.Wins(),
		DayCount = profile.DayCount(),
		CurrentZone = profile.CurrentZone(),
		CurrentClass = profile.CurrentClass(),

		TimeSpent = profile.TimeSpent(),
		RobuxSpent = profile.RobuxSpent(),
		GemsSpent = profile.GemsSpent(),
		ChestOpen = profile.ChestOpen(),
		SpinWheel = profile.SpinWheel(),

		MusicVolume = profile.MusicVolume(),
		SoundVolume = profile.SoundVolume(),
		MusicEnabled = profile.MusicEnabled(),
		SoundEnabled = profile.SoundEnabled(),
	})
end

function ProfileService:Bind(player: Player, session: any): Profile
	const profile = {}
	for key, value in session.Data do
		profile[key] = self.Libs.Charm.atom(value)
	end
	self.Profiles[player] = profile :: any

	self.Disposers[player] = self.Libs.Charm.effect(function()
		for key, field in profile do
			session.Data[key] = field()
		end
		self:Replicate(player)
	end)

	return profile :: any
end

function ProfileService:Load(player: Player)
	const session = self.Store:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not session then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end

	session:AddUserId(player.UserId)
	session:Reconcile()
	session.OnSessionEnd:Connect(function()
		if self.Sessions[player] == nil then
			return
		end
		self:Forget(player)
		if self.Dependencies.TeleportGateway:IsTeleporting(player) or player.Parent ~= Players then
			return
		end
		player:Kick("Your data session ended. Please rejoin.")
	end)

	if player.Parent ~= Players then
		session:EndSession()
		return
	end

	self.Sessions[player] = session
	self.Loaded:Fire(player, self:Bind(player, session))
end

function ProfileService:Forget(player: Player)
	const dispose = self.Disposers[player]
	if dispose then
		dispose()
		self.Disposers[player] = nil
	end
	self.Profiles[player] = nil
	self.Sessions[player] = nil
end

function ProfileService:Unload(player: Player)
	const session = self.Sessions[player]
	self:Forget(player)
	if session then
		session:EndSession()
	end
end

ProfileService:OnInit(function(self)
	self:Setup()

	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
		self:Begin(player)
	end)
	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.Started[player] = nil
		self:Unload(player)
	end)

	self.Dependencies.NetService.ClientReady:Connect(function(player)
		self:Replicate(player)
	end)
end)

ProfileService:OnStart(function(self)
	const roleService = self.Dependencies.ServerRoleService
	roleService:OnReady(function()
		if roleService:IsRouter() then
			return
		end

		self.Enabled = true
		for _, player in Players:GetPlayers() do
			self:Begin(player)
		end
	end)
end)

return ProfileService
