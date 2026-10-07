--!strict
const BASE_XP = 100
const GROWTH = 1.15
const LEVEL_CEILING = 1000

local function xpForLevel(level: number): number
	return math.round(BASE_XP * GROWTH ^ (math.max(level, 1) - 1))
end

local function apply(level: number, xp: number, gained: number): (number, number)
	local currentLevel = math.clamp(math.floor(level), 1, LEVEL_CEILING)
	local currentXp = math.max(xp, 0) + math.max(gained, 0)

	while currentLevel < LEVEL_CEILING do
		const needed = xpForLevel(currentLevel)
		if currentXp < needed then
			break
		end
		currentXp -= needed
		currentLevel += 1
	end

	if currentLevel >= LEVEL_CEILING then
		currentXp = 0
	end

	return currentLevel, currentXp
end

return {
	LevelCeiling = LEVEL_CEILING,
	XpForLevel = xpForLevel,
	Apply = apply,
}
