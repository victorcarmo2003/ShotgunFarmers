--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent
local Types = require(Package.Types)

local function Child(x: { Types.Child }): Types.Child
	return x
end

return Child
