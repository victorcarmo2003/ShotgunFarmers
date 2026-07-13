local CollectionService = game:GetService("CollectionService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)

-- Tag a colocar (no Studio) em instâncias SpawnLocation espalhadas pelo mapa de FFA.
local SPAWN_TAG = "FFASpawn"

local SpawnService = Modux.Service("SpawnService"):Import("PlayerService")

SpawnService.GetSpawnPoints = function(self): { BasePart }
	return CollectionService:GetTagged(SPAWN_TAG) :: { BasePart }
end

-- (Re)carrega o character do jogador imediatamente, sem checar o estado do round.
-- Uso interno/de baixo nível -- de fora, prefira RequestSpawn.
SpawnService.SpawnPlayer = function(self, Player: Player)
	print(`[SpawnService] SpawnPlayer chamado -- {Player.Name}`)

	if not Player:IsDescendantOf(game) then
		print(`[SpawnService] SpawnPlayer abortado -- {Player.Name} não é mais descendente do game`)
		return
	end
	Player:LoadCharacterAsync()
	print(`[SpawnService] LoadCharacterAsync concluído -- {Player.Name}, Character={tostring(Player.Character)}`)

	local spawnPoints = self:GetSpawnPoints()
	print(`[SpawnService] {#spawnPoints} spawn point(s) com a tag "{SPAWN_TAG}"`)
	if #spawnPoints > 0 then
		local spawnPoint = spawnPoints[math.random(1, #spawnPoints)]
		local character = Player.Character
		if character then
			character:PivotTo(spawnPoint:GetPivot() + Vector3.new(0, 2, 0))
		end
	end
end

-- FFA não pausa respawn entre fases do round -- Starting/Intermission/Vote só
-- afetam o timer/HUD (ver GameService), o corpo sempre renasce em ponto aleatório
-- alguns segundos depois de morrer (delay do ragdoll fica em VitalService.OnPlayerDie).
SpawnService.RequestSpawn = function(self, Player: Player)
	self:SpawnPlayer(Player)
end

SpawnService:OnInit(function(self)
	self.PlayerService:OnPlayerAdded(function(Player: Player)
		self:RequestSpawn(Player)
	end)

	self.PlayerService:OnCharacterRemoved(function(_character, Player: Player)
		self:RequestSpawn(Player)
	end)
end)

SpawnService:OnStart(function(self) end)

return SpawnService
