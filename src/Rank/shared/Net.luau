--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)
local RankSettings = require(ReplicatedStorage.shared.Rank.RankSettings)

local function category()
	return Lync.enum({ "Level", "Wins", "Kills", "Headshots" })
end

return Lync.define("Rank", {
	Board = Lync.packet(Lync.struct({
		Category = category(),
		Entries = Lync.array(
			Lync.struct({
				UserId = Lync.f64(),
				Name = Lync.str(0, 40),
				Value = Lync.f64(),
			}),
			0,
			RankSettings.TOP_SIZE
		),
	})),

	Mine = Lync.packet(Lync.array(
		Lync.struct({
			Category = category(),
			Value = Lync.f64(),
		}),
		0,
		#RankSettings.IDS
	)),
})
