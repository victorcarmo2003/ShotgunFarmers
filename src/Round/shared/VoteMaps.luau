--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Maps = require(ReplicatedStorage.shared.Match.Maps)

const PRACTICE_MODE = "Practice"
const MAX_OPTIONS = 16

local function list(modeName: string): { string }
	const names: { string } = {}
	if modeName == PRACTICE_MODE then
		return names
	end

	for mapName, map in Maps do
		if table.find(map.Modes, modeName) then
			table.insert(names, mapName)
		end
	end

	table.sort(names)
	while #names > MAX_OPTIONS do
		table.remove(names)
	end
	return names
end

return {
	MAX_OPTIONS = MAX_OPTIONS,
	list = list,
}
