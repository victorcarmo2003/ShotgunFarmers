--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)

local checkLifetime = require(Package.Memory.checkLifetime)

local castToState = require(Package.State.castToState)

local keyCache: { [string]: Types.SpecialKey } = {}

local function AttributeOut(attributeName: string): Types.SpecialKey
	local key = keyCache[attributeName]
	if key == nil then
		key = {
			type = "SpecialKey",
			kind = "AttributeOut",
			stage = "observer",
			apply = function(self: Types.SpecialKey, scope: Types.Scope<unknown>, value: unknown, applyTo: Instance)
				local event = applyTo:GetAttributeChangedSignal(attributeName)

				if not castToState(value) then
					External.logError("invalidAttributeOutType")
				end
				local value = value :: Types.StateObject<unknown>
				if value.kind ~= "Value" then
					External.logError("invalidAttributeOutType")
				end
				local value = value :: Types.Value<unknown>
				checkLifetime.bOutlivesA(
					scope,
					applyTo,
					value.scope,
					value.oldestTask,
					checkLifetime.formatters.attributeOutputsTo,
					attributeName
				)

				value:set((applyTo :: any):GetAttribute(attributeName))
				table.insert(
					scope,
					event:Connect(function()
						value:set((applyTo :: any):GetAttribute(attributeName))
					end)
				)
			end,
		}
		keyCache[attributeName] = key
	end
	return key
end

return AttributeOut
