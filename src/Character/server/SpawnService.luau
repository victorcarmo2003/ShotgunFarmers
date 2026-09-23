--!strict
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const SPAWN_TAG = "FFASpawn"
const SPAWN_OFFSET = Vector3.new(0, 2, 0)

const SpawnService = Modux.Service("SpawnService", { Require = { "PlayerService" }, Priority = 780 })

function SpawnService:GetSpawnPoints(): { BasePart }

	const points: { BasePart } = {}
	for _, tagged in CollectionService:GetTagged(SPAWN_TAG) do
		if tagged:IsA("BasePart") then
			table.insert(points, tagged)
		end
	end
	return points
end

function SpawnService:PlaceCharacter(character: Model)
	const points = self:GetSpawnPoints()
	if #points == 0 then
		return
	end

	const point = points[math.random(1, #points)]
	character:PivotTo(point:GetPivot() + SPAWN_OFFSET)
end

function SpawnService:SpawnPlayer(player: Player)
	if not player:IsDescendantOf(game) then
		return
	end

	player:LoadCharacter()
end

SpawnService:OnInit(function(self)
	self.Dependencies.PlayerService.CharacterAdded:Connect(function(_player, character)
		self:PlaceCharacter(character)
	end)
end)

return SpawnService
