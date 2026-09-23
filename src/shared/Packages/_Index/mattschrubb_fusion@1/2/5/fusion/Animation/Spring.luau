--!nonstrict

local Package = script.Parent.Parent
local PubTypes = require(Package.PubTypes)
local Types = require(Package.Types)
local logError = require(Package.Logging.logError)
local logErrorNonFatal = require(Package.Logging.logErrorNonFatal)
local unpackType = require(Package.Animation.unpackType)
local SpringScheduler = require(Package.Animation.SpringScheduler)
local useDependency = require(Package.Dependencies.useDependency)
local initDependency = require(Package.Dependencies.initDependency)
local updateAll = require(Package.Dependencies.updateAll)
local xtypeof = require(Package.Utility.xtypeof)
local unwrap = require(Package.State.unwrap)

local class = {}

local CLASS_METATABLE = { __index = class }
local WEAK_KEYS_METATABLE = { __mode = "k" }

function class:get(asDependency: boolean?): any
	if asDependency ~= false then
		useDependency(self)
	end
	return self._currentValue
end

function class:setPosition(newValue: PubTypes.Animatable)
	local newType = typeof(newValue)
	if newType ~= self._currentType then
		logError("springTypeMismatch", nil, newType, self._currentType)
	end

	self._springPositions = unpackType(newValue, newType)
	self._currentValue = newValue
	SpringScheduler.add(self)
	updateAll(self)
end

function class:setVelocity(newValue: PubTypes.Animatable)
	local newType = typeof(newValue)
	if newType ~= self._currentType then
		logError("springTypeMismatch", nil, newType, self._currentType)
	end

	self._springVelocities = unpackType(newValue, newType)
	SpringScheduler.add(self)
end

function class:addVelocity(deltaValue: PubTypes.Animatable)
	local deltaType = typeof(deltaValue)
	if deltaType ~= self._currentType then
		logError("springTypeMismatch", nil, deltaType, self._currentType)
	end

	local springDeltas = unpackType(deltaValue, deltaType)
	for index, delta in ipairs(springDeltas) do
		self._springVelocities[index] += delta
	end
	SpringScheduler.add(self)
end

function class:update(): boolean
	local goalValue = self._goalState:get(false)

	if goalValue == self._goalValue then
		local damping = unwrap(self._damping)
		if typeof(damping) ~= "number" then
			logErrorNonFatal("mistypedSpringDamping", nil, typeof(damping))
		elseif damping < 0 then
			logErrorNonFatal("invalidSpringDamping", nil, damping)
		else
			self._currentDamping = damping
		end

		local speed = unwrap(self._speed)
		if typeof(speed) ~= "number" then
			logErrorNonFatal("mistypedSpringSpeed", nil, typeof(speed))
		elseif speed < 0 then
			logErrorNonFatal("invalidSpringSpeed", nil, speed)
		else
			self._currentSpeed = speed
		end

		return false
	else
		self._goalValue = goalValue

		local oldType = self._currentType
		local newType = typeof(goalValue)
		self._currentType = newType

		local springGoals = unpackType(goalValue, newType)
		local numSprings = #springGoals
		self._springGoals = springGoals

		if newType ~= oldType then
			self._currentValue = self._goalValue

			local springPositions = table.create(numSprings, 0)
			local springVelocities = table.create(numSprings, 0)
			for index, springGoal in ipairs(springGoals) do
				springPositions[index] = springGoal
			end
			self._springPositions = springPositions
			self._springVelocities = springVelocities

			SpringScheduler.remove(self)
			return true
		elseif numSprings == 0 then
			self._currentValue = self._goalValue
			return true
		else
			SpringScheduler.add(self)
			return false
		end
	end
end

local function Spring<T>(
	goalState: PubTypes.Value<T>,
	speed: PubTypes.CanBeState<number>?,
	damping: PubTypes.CanBeState<number>?
): Types.Spring<T>
	if speed == nil then
		speed = 10
	end
	if damping == nil then
		damping = 1
	end

	local dependencySet = { [goalState] = true }
	if xtypeof(speed) == "State" then
		dependencySet[speed] = true
	end
	if xtypeof(damping) == "State" then
		dependencySet[damping] = true
	end

	local self = setmetatable({
		type = "State",
		kind = "Spring",
		dependencySet = dependencySet,

		dependentSet = setmetatable({}, WEAK_KEYS_METATABLE),
		_speed = speed,
		_damping = damping,

		_goalState = goalState,
		_goalValue = nil,

		_currentType = nil,
		_currentValue = nil,
		_currentSpeed = unwrap(speed),
		_currentDamping = unwrap(damping),

		_springPositions = nil,
		_springGoals = nil,
		_springVelocities = nil,
	}, CLASS_METATABLE)

	initDependency(self)

	goalState.dependentSet[self] = true
	self:update()

	return self
end

return Spring
