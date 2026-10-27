--!strict
export type Category = "Level" | "Wins" | "Kills" | "Headshots"

export type Entry = {
	UserId: number,
	Name: string,
	Value: number,
}

export type CategoryInfo = {
	Id: Category,
	Label: string,
}

const RankSettings = {}

RankSettings.CATEGORIES = {
	{ Id = "Level", Label = "LEVEL" },
	{ Id = "Wins", Label = "WINS" },
	{ Id = "Kills", Label = "KILLS" },
	{ Id = "Headshots", Label = "HEADSHOTS" },
} :: { CategoryInfo }

RankSettings.IDS = { "Level", "Wins", "Kills", "Headshots" } :: { Category }

RankSettings.TOP_SIZE = 50
RankSettings.STORE_PREFIX = "Ranks_v1_"
RankSettings.SAVE_INTERVAL = 120
RankSettings.REFRESH_INTERVAL = 90

RankSettings.LEVEL_SCALE = 10000000

function RankSettings.Display(category: Category, stored: number): number
	if category == "Level" then
		return math.floor(stored / RankSettings.LEVEL_SCALE)
	end
	return stored
end

return RankSettings
