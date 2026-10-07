--!strict
export type State = "Loading" | "Lobby" | "Starting" | "Playing" | "Intermission" | "Vote"
export type Capability = "FirstPerson" | "Viewmodel" | "Hud" | "Combat" | "Loadout"

const ATTRIBUTE = "GameState"

const STATES: { [string]: boolean } = {
	Loading = true,
	Lobby = true,
	Starting = true,
	Playing = true,
	Intermission = true,
	Vote = true,
}

const FROM_ROUND: { [string]: State } = {
	Starting = "Starting",
	Match = "Playing",
	Intermission = "Intermission",
	Vote = "Vote",
}

const CAPABILITIES: { [State]: { [Capability]: boolean } } = {
	Loading = { FirstPerson = false, Viewmodel = false, Hud = false, Combat = false, Loadout = false },
	Lobby = { FirstPerson = false, Viewmodel = false, Hud = false, Combat = false, Loadout = false },
	Starting = { FirstPerson = true, Viewmodel = true, Hud = true, Combat = false, Loadout = true },
	Playing = { FirstPerson = true, Viewmodel = true, Hud = true, Combat = true, Loadout = true },
	Intermission = { FirstPerson = true, Viewmodel = true, Hud = true, Combat = false, Loadout = true },
	Vote = { FirstPerson = false, Viewmodel = false, Hud = true, Combat = false, Loadout = true },
}

local function fromRound(status: string): State
	return FROM_ROUND[status] or "Loading"
end

local function parse(value: any): State
	if typeof(value) == "string" and STATES[value] then
		return value :: State
	end

	return "Loading"
end

local function can(state: State, capability: Capability): boolean
	return CAPABILITIES[state][capability] == true
end

local function isInMatch(state: State): boolean
	return state ~= "Loading" and state ~= "Lobby"
end

return {
	ATTRIBUTE = ATTRIBUTE,
	fromRound = fromRound,
	parse = parse,
	can = can,
	isInMatch = isInMatch,
}
