--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)

local change = require(Package.Graph.change)

local isSimilar = require(Package.Utility.isSimilar)
local never = require(Package.Utility.never)
local nicknames = require(Package.Utility.nicknames)

type Self<T, S> = Types.Value<T, S>

local class = {}
class.type = "State"
class.kind = "Value"
class.timeliness = "lazy"
class.dependencySet = table.freeze({})

local METATABLE = table.freeze({ __index = class })

local function Value<T>(scope: Types.Scope<unknown>, initialValue: T): Types.Value<T, any>
	local createdAt = os.clock()
	if initialValue == nil and (typeof(scope) ~= "table" or (scope[1] == nil and next(scope) ~= nil)) then
		External.logError("scopeMissing", nil, "Value", "myScope:Value(initialValue)")
	end
	local self: Self<T, any> = setmetatable({
		createdAt = createdAt,
		dependentSet = {},
		lastChange = os.clock(),
		scope = scope,
		validity = "valid",
		_EXTREMELY_DANGEROUS_usedAsValue = initialValue,
	}, METATABLE) :: any
	local destroy = function()
		self.scope = nil
	end
	self.oldestTask = destroy
	nicknames[self.oldestTask] = "Value"
	table.insert(scope, destroy)
	return self
end

function class:get<T, S>(_self: Self<T, S>): never
	External.logError("stateGetWasRemoved")
	return never()
end

function class.set<T, S>(self: Self<T, S>, newValue: S): S
	local oldValue = self._EXTREMELY_DANGEROUS_usedAsValue
	if not isSimilar(oldValue, newValue) then
		self._EXTREMELY_DANGEROUS_usedAsValue = newValue :: any
		change(self)
	end
	return newValue
end

function class._evaluate<T, S>(_self: Self<T, S>): boolean
	return true
end

table.freeze(class)
return Value :: Types.ValueConstructor
