--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

const RESPAWN_DELAY = 3
const RESET_COOLDOWN = 1

const VitalService = Modux.Service("VitalService", { Require = { "PlayerService", "SpawnService" }, Priority = 700 })

function VitalService:Setup()
	self.Died = self.Libs.Signal.new() :: SignalLib.Signal<Player>
	self.Restored = self.Libs.Signal.new() :: SignalLib.Signal<Player>
	self.Dead = {} :: { [Player]: boolean }
	self.LastReset = {} :: { [Player]: number }
	self.Watched = setmetatable({}, { __mode = "k" }) :: { [Humanoid]: boolean }
end

function VitalService:Reset(player: Player)
	const now = os.clock()
	const last = self.LastReset[player]
	if last and now - last < RESET_COOLDOWN then
		return
	end
	self.LastReset[player] = now

	const vital = self.Components.Vital:Get(player)
	if not vital or not vital.Alive then
		return
	end
	vital:TakeDamage(vital.Health + vital.Armor)
end

function VitalService:Watch(player: Player, character: Model)
	const humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or self.Watched[humanoid] then
		return
	end
	self.Watched[humanoid] = true

	humanoid.Died:Once(function()
		if player.Character ~= character then
			return
		end
		const vital = self.Components.Vital:Get(player)
		if vital and vital.Alive then
			vital:TakeDamage(vital.Health + vital.Armor)
		end
	end)
end

function VitalService:Kill(player: Player)
	if self.Dead[player] then
		return
	end
	self.Dead[player] = true

	const character = player.Character
	if character then
		const humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end

	self.Dependencies.SpawnService:Respawn(player, RESPAWN_DELAY)
	self.Died:Fire(player)
end

VitalService:OnInit(function(self)
	self:Setup()

	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
		self.Components.Vital:Create(player)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.Components.Vital:Destroy(player)
		self.Dead[player] = nil
		self.LastReset[player] = nil
	end)

	self.Dependencies.PlayerService.CharacterAdded:Connect(function(player, character)
		self.Dead[player] = nil
		const vital = self.Components.Vital:Get(player)
		if vital then
			vital:Revive()
		end
		self:Watch(player, character)
	end)

	self.Libs.Net.Vital.RequestReset:onServer(function(_, player)
		self:Reset(player)
	end)
end)

return VitalService
