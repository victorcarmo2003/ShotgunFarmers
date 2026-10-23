--!strict
export type Reward = {
	Gems: number?,
	Xp: number?,
}

const Codes: { [string]: Reward } = {
	LAUNCH = { Gems = 5000 },
	LAUNCHXP = { Xp = 250 },
}

local function normalize(code: string): string
	return string.upper((string.gsub(code, "%s", "")))
end

local function find(code: string): Reward?
	return Codes[normalize(code)]
end

return {
	Codes = Codes,
	Normalize = normalize,
	Find = find,
}
