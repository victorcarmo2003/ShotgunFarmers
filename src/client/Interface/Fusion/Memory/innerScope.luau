--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent
local Types = require(Package.Types)
local ExternalDebug = require(Package.ExternalDebug)
local deriveScopeImpl = require(Package.Memory.deriveScopeImpl)

local function innerScope<T>(existing: Types.Scope<T>, ...: { [unknown]: unknown }): any
	local new = deriveScopeImpl(existing, ...)
	table.insert(existing, new)
	table.insert(new, function()
		local index = table.find(existing, new)
		if index ~= nil then
			table.remove(existing, index)
		end
	end)
	ExternalDebug.trackScope(new)
	return new
end

return (innerScope :: any) :: Types.DeriveScopeConstructor
