local Modux = require(game.ReplicatedStorage.Shared.Modux)
local IDService = Modux.Service("IDService"):Import("PlayerService")
type Self = typeof(IDService)
IDService.nextID = 0
IDService.allPlayers = {} :: { [Player]: number }

IDService.GetNextID = function(self: Self): number
	self.nextID += 1
	return self.nextID
end

IDService.GetPlayerFromID = function(self: Self, ID: number): Player?
	for player, id in self.allPlayers do
		if id == ID then
			return player
		end
	end
	return nil
end

IDService.GetPlayerID = function(self: Self, Player: Player)
	for player, id in self.allPlayers do
		if player == Player then
			return id
		end
	end
	return self:RegisterPlayer(Player)
end

IDService.RegisterPlayer = function(self: Self, Player: Player): number
	local id = self:GetNextID()
	self.allPlayers[Player] = id
	Player:SetAttribute("GameID", id)
	return id
end

IDService:OnInit(function(self)
	self.allPlayers = setmetatable(self.allPlayers, { __mode = "k" })
	self.PlayerService:OnPlayerAdded(function(Player: Player)
		-- warn(Player)
		self:RegisterPlayer(Player)
	end)
end)

return IDService
