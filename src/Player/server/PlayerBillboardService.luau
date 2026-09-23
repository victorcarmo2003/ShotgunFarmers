--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const PlayerBillboardService = Modux.Service("PlayerBillboardService", { Require = { "PlayerService" }, Priority = 550 })

function PlayerBillboardService:Setup()
	const asset = ReplicatedStorage.Assets:FindFirstChild("PlayerBillboard")
	self.Template = (if asset and asset:IsA("BillboardGui") then asset else nil) :: BillboardGui?
end

function PlayerBillboardService:Attach(player: Player, character: Model)
	const template = self.Template
	if not template then
		return
	end

	const anchor = character.PrimaryPart
	if not anchor then
		return
	end

	const billboard = template:Clone()
	const label = billboard:FindFirstChild("TextLabel")
	if label and label:IsA("TextLabel") then
		label.Text = player.DisplayName
	end
	billboard.Parent = anchor
end

PlayerBillboardService:OnInit(function(self)
	self:Setup()

	self.Dependencies.PlayerService.CharacterAdded:Connect(function(player, character)
		self:Attach(player, character)
	end)
end)

return PlayerBillboardService
