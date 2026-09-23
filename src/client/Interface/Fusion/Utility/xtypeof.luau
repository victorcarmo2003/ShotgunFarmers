--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local function xtypeof(x: unknown): string
	local typeString = typeof(x)

	if typeString == "table" then
		local x = x :: { type: unknown? }
		if typeof(x.type) == "string" then
			return x.type
		end
	end

	return typeString
end

return xtypeof
