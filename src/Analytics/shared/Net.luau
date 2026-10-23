--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

return Lync.define("Analytics", {
	Track = Lync.packet(Lync.struct({
		Funnel = Lync.enum({
			"Matchmaking",
			"PlantLoop",
			"Rounds",
			"Revive",
			"RobuxShop",
			"Skins",
			"Party",
			"PrivateRoom",
			"Practice",
		}),
		Step = Lync.str(1, 32),
		Detail = Lync.str(0, 32),
	})),
})
