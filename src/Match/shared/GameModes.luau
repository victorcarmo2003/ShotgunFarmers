--!strict

export type Mode = {
	DisplayName: string,
	Teams: boolean,
	TeamSize: number,
	ScoreLimit: number,
	Ranked: boolean,
	AllowJoinInProgress: boolean,
	MaxPlayers: number?,
}

const Modes: { [string]: Mode } = {
	FFA = {
		DisplayName = "Free For All",
		Teams = false,
		TeamSize = 1,
		ScoreLimit = 30,
		Ranked = false,
		AllowJoinInProgress = true,
		MaxPlayers = 10,
	},
	TDM = {
		DisplayName = "Team Deathmatch",
		Teams = true,
		TeamSize = 10,
		ScoreLimit = 75,
		Ranked = false,
		AllowJoinInProgress = true,
	},
	Chicken = {
		DisplayName = "Chicken",
		Teams = true,
		TeamSize = 10,
		ScoreLimit = 10,
		Ranked = false,
		AllowJoinInProgress = true,
	},
	Practice = {
		DisplayName = "Practice",
		Teams = false,
		TeamSize = 1,
		ScoreLimit = 30,
		Ranked = false,
		AllowJoinInProgress = false,
		MaxPlayers = 5,
	},
}

local function getMaxPlayers(modeName: string): number
	const mode = Modes[modeName]
	if not mode then
		return 0
	end

	if mode.MaxPlayers then
		return mode.MaxPlayers
	end

	return if mode.Teams then mode.TeamSize * 2 else mode.TeamSize
end

return {
	Modes = Modes,
	GetMaxPlayers = getMaxPlayers,
}
