--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const IDService = Modux.Service("IDService", { Require = { "PlayerService" }, Priority = 850 })

function IDService:Setup()
	self.NextID = 0 :: number

	self.PlayerIDs = {} :: { [Player]: number }

	self.IDPlayers = {} :: { [number]: Player }
end

function IDService:GetNextID(): number
	self.NextID += 1
	return self.NextID
end

function IDService:RegisterPlayer(player: Player): number
	const id = self:GetNextID()
	self.PlayerIDs[player] = id
	self.IDPlayers[id] = player
	player:SetAttribute("GameID", id)
	return id
end

function IDService:GetPlayerID(player: Player): number
	const existing = self.PlayerIDs[player]
	if existing then
		return existing
	end
	return self:RegisterPlayer(player)
end

function IDService:GetPlayerFromID(id: number): Player?
	return self.IDPlayers[id]
end

function IDService:Unregister(player: Player)
	const id = self.PlayerIDs[player]
	if not id then
		return
	end
	self.PlayerIDs[player] = nil
	self.IDPlayers[id] = nil
end

IDService:OnInit(function(self)
	self:Setup()

	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
		self:RegisterPlayer(player)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Unregister(player)
	end)
end)

return IDService
