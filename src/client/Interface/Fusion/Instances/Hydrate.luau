--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local applyInstanceProps = require(Package.Instances.applyInstanceProps)

local function Hydrate(scope: Types.Scope<unknown>, target: Instance)
	if target :: any == nil then
		External.logError("scopeMissing", nil, "instances using Hydrate", "myScope:Hydrate (instance) { ... }")
	end
	return function(props: Types.PropertyTable): Instance
		table.insert(scope, target)
		applyInstanceProps(scope, props, target)
		return target
	end
end

return Hydrate
