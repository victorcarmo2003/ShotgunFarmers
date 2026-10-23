--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const TAG = "LavaFloor"
const DAMAGE_PER_SECOND = 30
const TICK_RATE = 10
const FEET_PROBE = Vector3.new(2, 1, 2)
const FEET_OFFSET = 0.5

const LavaService = Modux.Service("LavaService", {
	Require = { "VitalService" },
	Priority = 260,
})

function LavaService:Setup()
	const params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.RespectCanCollide = false
	self.Params = params :: OverlapParams
end

function LavaService:IsOnLava(character: Model, lava: { Instance }): boolean
	const root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	const humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return false
	end

	const depth = humanoid.HipHeight + root.Size.Y / 2 + FEET_OFFSET
	const feet = root.CFrame * CFrame.new(0, -depth, 0)
	self.Params.FilterDescendantsInstances = lava
	return #workspace:GetPartBoundsInBox(feet, FEET_PROBE, self.Params) > 0
end

function LavaService:Step()
	const lava = CollectionService:GetTagged(TAG)
	if #lava == 0 then
		return
	end

	const damage = DAMAGE_PER_SECOND / TICK_RATE
	for _, player in Players:GetPlayers() do
		const character = player.Character
		if not character or self.Dependencies.VitalService:IsDead(player) then
			continue
		end
		if not self:IsOnLava(character, lava) then
			continue
		end
		const vital = self.Components.Vital:Get(player)
		if vital and vital.Alive then
			vital:TakeDamage(damage)
		end
	end
end

LavaService:OnInit(function(self)
	self:Setup()
end)

LavaService:OnTick(function(self)
	self:Step()
end, TICK_RATE)

return LavaService
