--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)

local depend = require(Package.Graph.depend)

local peek = require(Package.State.peek)
local castToState = require(Package.State.castToState)
local ForTypes = require(Package.State.For.ForTypes)

local doCleanup = require(Package.Memory.doCleanup)
local deriveScope = require(Package.Memory.deriveScope)
local scopePool = require(Package.Memory.scopePool)

local nameOf = require(Package.Utility.nameOf)
local nicknames = require(Package.Utility.nicknames)

type Self<S, KI, KO, VI, VO> = ForTypes.Disassembly<S, KI, KO, VI, KO> & {
	scope: (S & Types.Scope<unknown>)?,
	_inputTable: Types.UsedAs<{ [KI]: VI }>,
	_constructor: (Types.Scope<S>, initialKey: KI, initialValue: VI) -> ForTypes.SubObject<S, KI, KO, VI, VO>,
	_subObjects: { [ForTypes.SubObject<S, KI, KO, VI, VO>]: true },
}

local class = {}
class.type = "Graph"
class.kind = "For.Disassembly"
class.timeliness = "lazy"

local METATABLE = table.freeze({ __index = class })

local function Disassembly<S, KI, KO, VI, VO>(
	scope: S & Types.Scope<unknown>,
	inputTable: Types.UsedAs<{ [KI]: VI }>,
	constructor: (
		Types.Scope<S>,
		initialKey: KI,
		initialValue: VI
	) -> ForTypes.SubObject<S, KI, KO, VI, VO>
): ForTypes.Disassembly<S, KI, KO, VI, KO>
	local createdAt = os.clock()
	local self = setmetatable({
		createdAt = createdAt,
		dependencySet = {},
		dependentSet = {},
		scope = scope,
		validity = "invalid",
		_inputTable = inputTable,
		_constructor = constructor,
		_subObjects = {},
	}, METATABLE) :: any

	local destroy = function()
		self.scope = nil
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = nil
		end
		for subObject in self._subObjects do
			if subObject.maybeScope ~= nil then
				doCleanup(subObject.maybeScope)
				subObject.maybeScope = nil
			end
		end
	end
	self.oldestTask = destroy
	nicknames[self.oldestTask] = "For (internal disassembler)"
	table.insert(scope, destroy)

	return self
end

function class.populate<S, KI, KO, VI, VO>(self: Self<S, KI, KO, VI, VO>, use: Types.Use, output: { [KO]: VO }): ()
	local minArrayIndex = math.huge
	local maxArrayIndex = -math.huge
	local hasHoles = false
	for subObject in self._subObjects do
		local outputKey, outputValue = subObject:useOutputPair(use)
		if outputKey == nil or outputValue == nil then
			hasHoles = true
			continue
		elseif output[outputKey] ~= nil then
			External.logErrorNonFatal("forKeyCollision", nil, tostring(outputKey))
			continue
		end
		output[outputKey] = outputValue
		if typeof(outputKey) == "number" then
			minArrayIndex = math.min(minArrayIndex, outputKey)
			maxArrayIndex = math.max(maxArrayIndex, outputKey)
		end
	end

	if hasHoles and maxArrayIndex > minArrayIndex then
		local output: { [number]: VO } = output :: any
		local moveToIndex = minArrayIndex
		for moveFromIndex = minArrayIndex, maxArrayIndex do
			local outputValue = output[moveFromIndex]
			if outputValue == nil then
				continue
			end

			output[moveFromIndex] = nil
			output[moveToIndex] = outputValue
			moveToIndex += 1
		end
	end
end

function class._evaluate<S, KI, KO, VI, VO>(self: Self<S, KI, KO, VI, VO>): boolean
	local outerScope = self.scope :: S & Types.Scope<unknown>
	local inputState = castToState(self._inputTable)
	if inputState ~= nil then
		if inputState.scope == nil then
			External.logError(
				"useAfterDestroy",
				nil,
				`The input {nameOf(inputState, "table")}`,
				`the For object that is watching it`
			)
		end
		depend(self, inputState)
	end

	local pendingPairs = {} :: { [KI]: VI }
	for key, value in peek(self._inputTable) do
		pendingPairs[key] = value
	end

	local newSubObjects = {} :: typeof(self._subObjects)

	for subObject in self._subObjects do
		local reused = false
		local oldInputKey = subObject.inputKey
		local oldInputValue = subObject.inputValue
		local newInputKey: KI

		if not subObject.roamKeys and pendingPairs[oldInputKey] ~= nil then
			reused = true
			newInputKey = oldInputKey
		else
			for pendingKey, pendingValue in pendingPairs do
				reused = true
				newInputKey = pendingKey
				if subObject.roamValues then
					break
				end
				if pendingValue == oldInputValue then
					break
				end
			end
		end
		if reused then
			local newInputValue = pendingPairs[newInputKey]
			newSubObjects[subObject] = true
			if newInputKey ~= oldInputKey then
				subObject.inputKey = newInputKey
				subObject:invalidateInputKey()
			end
			if newInputValue ~= oldInputValue then
				subObject.inputValue = newInputValue
				subObject:invalidateInputValue()
			end
			pendingPairs[newInputKey] = nil
		else
			if subObject.maybeScope ~= nil then
				doCleanup(subObject.maybeScope)
				subObject.maybeScope = nil
			end
		end
	end

	for pendingKey, pendingValue in pendingPairs do
		local subObject = self._constructor(deriveScope(outerScope), pendingKey, pendingValue)
		if subObject.maybeScope ~= nil then
			subObject.maybeScope = scopePool.giveIfEmpty(subObject.maybeScope)
		end
		newSubObjects[subObject] = true
	end

	self._subObjects = newSubObjects

	return true
end

table.freeze(class)
return Disassembly
