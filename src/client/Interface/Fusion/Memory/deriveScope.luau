--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent
local Types = require(Package.Types)
local ExternalDebug = require(Package.ExternalDebug)
local deriveScopeImpl = require(Package.Memory.deriveScopeImpl)

local function deriveScope(...)
	local scope = deriveScopeImpl(...)
	ExternalDebug.trackScope(scope)
	return scope
end

return deriveScope :: Types.DeriveScopeConstructor
