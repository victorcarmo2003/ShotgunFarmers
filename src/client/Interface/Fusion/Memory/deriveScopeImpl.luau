--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent
local Types = require(Package.Types)
local merge = require(Package.Utility.merge)
local scopePool = require(Package.Memory.scopePool)

local function deriveScopeImpl<T>(
	existing: Types.Scope<T>,
	methods: { [unknown]: unknown }?,
	...: { [unknown]: unknown }
): any
	local metatable = getmetatable(existing)
	if methods ~= nil then
		metatable = table.clone(metatable)
		metatable.__index = merge(true, {}, metatable.__index, merge(false, {}, methods, ...))
	end
	local scope = setmetatable(scopePool.reuseAny() :: any or {}, metatable)
	return scope
end

return (deriveScopeImpl :: any) :: Types.DeriveScopeConstructor
