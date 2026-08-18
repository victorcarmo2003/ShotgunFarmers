--!strict

local function needsDestruction(x: any): boolean
	return typeof(x) == "Instance"
end

return needsDestruction
