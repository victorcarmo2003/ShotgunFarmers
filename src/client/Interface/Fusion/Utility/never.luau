--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local function never(): never
	error("This codepath should not be reachable")
end

return never
