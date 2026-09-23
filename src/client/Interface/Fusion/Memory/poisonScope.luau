--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)

local function poisonScope(scope: Types.Scope, context: string): ()
	local mt = getmetatable(scope)
	if typeof(mt) == "table" and mt._FUSION_POISONED then
		return
	end
	table.clear(scope)
	setmetatable(scope :: any, {
		_FUSION_POISONED = true,
		__index = function()
			External.logError("poisonedScope", nil, context)
		end,
		__newindex = function()
			External.logError("poisonedScope", nil, context)
		end,
	})
end

return poisonScope
