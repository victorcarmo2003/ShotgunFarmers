--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)

local parseError = require(Package.Logging.parseError)

export type Self<T> = Types.Contextual<T> & {
	_valuesNow: { [thread]: { value: T } },
	_defaultValue: T,
}

local class = {}
class.type = "Contextual"

local METATABLE = table.freeze({ __index = class })
local WEAK_KEYS_METATABLE = table.freeze({ __mode = "k" })

local function Contextual<T>(defaultValue: T): Types.Contextual<T>
	local self: Self<T> = setmetatable({

		_valuesNow = setmetatable({}, WEAK_KEYS_METATABLE),
		_defaultValue = defaultValue,
	}, METATABLE) :: any

	return self
end

function class.now<T>(self: Self<T>): T
	local thread = coroutine.running()
	local value = self._valuesNow[thread]
	if typeof(value) ~= "table" then
		return self._defaultValue
	else
		return value.value
	end
end

function class.is<T>(self: Self<T>, newValue: T)
	local methods = {}

	function methods.during<T, A...>(_: any, callback: (A...) -> T, ...: A...): T
		local thread = coroutine.running()
		local prevValue = self._valuesNow[thread]

		self._valuesNow[thread] = { value = newValue }
		local ok, value = xpcall(callback, parseError, ...)
		self._valuesNow[thread] = prevValue
		if not ok then
			External.logError("callbackError", value :: any)
		end
		return value
	end

	return methods
end

table.freeze(class)
return Contextual
