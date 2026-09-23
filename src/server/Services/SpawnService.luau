local CollectionService = game:GetService("CollectionService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)

local SPAWN_TAG = "FFASpawn"

local SpawnService = Modux.Service("SpawnService"):Import("PlayerService")
type Self = typeof(SpawnService)

local RESPAWN_DELAY = 3

SpawnService.GetSpawnPoints = function(self: Self): { BasePart }
	return CollectionService:GetTagged(SPAWN_TAG) :: { BasePart }
end

SpawnService.SpawnPlayer = function(self: Self, Player: Player)
	if not Player:IsDescendantOf(game) then
		print(`[SpawnService] SpawnPlayer abortado -- {Player.Name} não é mais descendente do game`)
		return
	end
	Player:LoadCharacterAsync()
	print(`[SpawnService] LoadCharacterAsync concluído -- {Player.Name}, Character={tostring(Player.Character)}`)

	local spawnPoints = self:GetSpawnPoints()
	if #spawnPoints > 0 then
		local spawnPoint = spawnPoints[math.random(1, #spawnPoints)]
		local character = Player.Character
		if character then
			character:PivotTo(spawnPoint:GetPivot() + Vector3.new(0, 2, 0))
		end
	end
end

SpawnService.RequestSpawn = function(self: Self, Player: Player)
	self:SpawnPlayer(Player)
end

SpawnService.HandlePlayerDeath = function(self: Self, Player: Player)
	task.delay(RESPAWN_DELAY, function()
		print(`[SpawnService] Respawnando {Player.Name} depois do delay de ragdoll`)
		self:RequestSpawn(Player)
	end)
end

SpawnService:OnInit(function(self)
	self.PlayerService:OnPlayerAdded(function(Player: Player)
		self:RequestSpawn(Player)
	end)
end)

SpawnService:OnStart(function(self) end)

return SpawnService
