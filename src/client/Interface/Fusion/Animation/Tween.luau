--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)

local checkLifetime = require(Package.Memory.checkLifetime)

local depend = require(Package.Graph.depend)
local evaluate = require(Package.Graph.evaluate)

local castToState = require(Package.State.castToState)
local peek = require(Package.State.peek)

local ExternalTime = require(Package.Animation.ExternalTime)
local Stopwatch = require(Package.Animation.Stopwatch)
local lerpType = require(Package.Animation.lerpType)
local getTweenRatio = require(Package.Animation.getTweenRatio)
local getTweenDuration = require(Package.Animation.getTweenDuration)

local nicknames = require(Package.Utility.nicknames)

export type Self<T> = Types.Tween<T> & {
	_activeDuration: number,
	_activeElapsed: number,
	_activeFrom: T,
	_activeTo: T,
	_activeTweenInfo: TweenInfo,
	_goal: Types.UsedAs<T>,
	_stopwatch: Stopwatch.Stopwatch?,
	_tweenInfo: Types.UsedAs<TweenInfo>,
}

local class = {}
class.type = "State"
class.kind = "Tween"
class.timeliness = "eager"

local METATABLE = table.freeze({ __index = class })

local function Tween<T>(
	scope: Types.Scope<unknown>,
	goal: Types.UsedAs<T>,
	tweenInfo: Types.UsedAs<TweenInfo>?
): Types.Tween<T>
	local createdAt = os.clock()
	if castToState(scope) then
		External.logError("scopeMissing", nil, "Tweens", "myScope:Tween(goalState, tweenInfo)")
	end

	local goalState = castToState(goal)
	local stopwatch = nil
	if goalState ~= nil then
		stopwatch = Stopwatch(scope, ExternalTime(scope))
	end

	local self: Self<T> = setmetatable({
		createdAt = createdAt,
		dependencySet = {},
		dependentSet = {},
		lastChange = nil,
		scope = scope,
		validity = "invalid",
		_activeDuration = nil,
		_activeElapsed = nil,
		_activeFrom = nil,
		_activeTo = nil,
		_activeTweenInfo = nil,
		_EXTREMELY_DANGEROUS_usedAsValue = peek(goal),
		_goal = goal,
		_stopwatch = stopwatch,
		_tweenInfo = tweenInfo or TweenInfo.new(),
	}, METATABLE) :: any
	local destroy = function()
		self.scope = nil
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = nil
		end
	end
	self.oldestTask = destroy
	nicknames[self.oldestTask] = "Tween"
	table.insert(scope, destroy)

	if goalState ~= nil then
		checkLifetime.bOutlivesA(
			scope,
			self.oldestTask,
			goalState.scope,
			goalState.oldestTask,
			checkLifetime.formatters.animationGoal
		)
	end

	local tweenInfoState = castToState(tweenInfo)
	if tweenInfoState ~= nil then
		checkLifetime.bOutlivesA(
			scope,
			self.oldestTask,
			tweenInfoState.scope,
			tweenInfoState.oldestTask,
			checkLifetime.formatters.parameter,
			"tween info"
		)
	end

	evaluate(self, true)

	return self
end

function class.get<T>(self: Self<T>): never
	return External.logError("stateGetWasRemoved")
end

function class._evaluate<T>(self: Self<T>): boolean
	local goal = castToState(self._goal)

	if goal == nil then
		self._EXTREMELY_DANGEROUS_usedAsValue = self._goal :: T
		return false
	end
	depend(self, goal)
	local newTweenTo = peek(goal)

	if newTweenTo ~= newTweenTo then
		External.logWarn("tweenNanGoal")
		return false
	end
	local stopwatch = self._stopwatch :: Stopwatch.Stopwatch
	local tweenInfo = peek(self._tweenInfo) :: TweenInfo

	if
		self._activeTo ~= newTweenTo
		or (self._activeElapsed < self._activeDuration and self._activeTweenInfo ~= tweenInfo)
	then
		self._activeDuration = getTweenDuration(tweenInfo)
		self._activeFrom = self._EXTREMELY_DANGEROUS_usedAsValue
		self._activeTo = newTweenTo
		self._activeTweenInfo = tweenInfo
		stopwatch:zero()
		stopwatch:unpause()
	end
	depend(self, stopwatch)
	self._activeElapsed = peek(stopwatch)
	if
		self._activeFrom == self._activeTo
		or self._activeElapsed >= self._activeDuration
		or typeof(self._activeTo) ~= typeof(self._activeFrom)
	then
		self._activeFrom = self._activeTo
		self._activeElapsed = self._activeDuration
		stopwatch:pause()
	end

	local ratio = getTweenRatio(tweenInfo, self._activeElapsed)
	local oldValue = self._EXTREMELY_DANGEROUS_usedAsValue
	local newValue = lerpType(self._activeFrom, self._activeTo, ratio) :: T

	if newValue ~= newValue then
		External.logWarn("tweenNanMotion")
		newValue = self._activeTo
	end

	self._EXTREMELY_DANGEROUS_usedAsValue = newValue
	return oldValue ~= newValue
end

table.freeze(class)
return Tween :: Types.TweenConstructor
