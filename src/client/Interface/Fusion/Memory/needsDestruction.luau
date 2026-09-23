--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local function needsDestruction(x: unknown): boolean
	return typeof(x) == "Instance"
end

return needsDestruction
