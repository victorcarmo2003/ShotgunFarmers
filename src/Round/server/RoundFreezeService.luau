--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const FREEZE_STATUS = "Starting"
const PRACTICE_MODE = "Practice"
const ROOT_WAIT = 5

const RoundFreezeService = Modux.Service("RoundFreezeService", {
	Require = { "PlayerService", "RoundService", "ServerRoleService" },
	Priority = 550,
})

function RoundFreezeService:Setup()
	self.Frozen = false :: boolean
end

function RoundFreezeService:ShouldFreeze(): boolean
	const roleService = self.Dependencies.ServerRoleService
	if not roleService:IsMatch() then
		return false
	end

	const config = roleService:GetConfig()
	if config and config.Mode == PRACTICE_MODE then
		return false
	end

	return self.Dependencies.RoundService.Status() == FREEZE_STATUS
end

function RoundFreezeService:Apply(character: Model)
	const root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = self.Frozen
	end
end

function RoundFreezeService:ApplyAll()
	for _, player in Players:GetPlayers() do
		const character = player.Character
		if character then
			self:Apply(character)
		end
	end
end

function RoundFreezeService:Refresh()
	const frozen = self:ShouldFreeze()
	if frozen == self.Frozen then
		return
	end
	self.Frozen = frozen
	self:ApplyAll()
end

RoundFreezeService:OnInit(function(self)
	self:Setup()

	self.Dependencies.PlayerService.CharacterAdded:Connect(function(_player: Player, character: Model)
		if not self.Frozen then
			return
		end
		task.spawn(function()
			character:WaitForChild("HumanoidRootPart", ROOT_WAIT)
			if self.Frozen and character.Parent then
				self:Apply(character)
			end
		end)
	end)
end)

RoundFreezeService:OnStart(function(self)
	const roleService = self.Dependencies.ServerRoleService
	roleService:OnReady(function()
		self:Refresh()
		self.Libs.Charm.subscribe(self.Dependencies.RoundService.Status, function()
			self:Refresh()
		end)
	end)
end)

return RoundFreezeService
