--!strict

local function isSimilar(a: any, b: any): boolean
	if typeof(a) == "table" then
		return false
	else
		return a == b
	end
end

return isSimilar
