--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent
local Types = require(Package.Types)

local castToState = require(Package.State.castToState)

local evaluate = require(Package.Graph.evaluate)

local function peek<T>(target: Types.UsedAs<T>): T
	local targetState = castToState(target)
	if targetState ~= nil then
		evaluate(targetState, false)
		return targetState._EXTREMELY_DANGEROUS_usedAsValue :: T
	else
		return target :: T
	end
end

return peek
