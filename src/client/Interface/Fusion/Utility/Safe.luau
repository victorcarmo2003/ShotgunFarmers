--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent

local function Safe<Success, Fail>(callbacks: {
	try: () -> Success,
	fallback: (err: unknown) -> Fail,
}): Success | Fail
	local _, value = xpcall(callbacks.try, callbacks.fallback)
	return value
end

return Safe
