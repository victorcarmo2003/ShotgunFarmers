--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent
local formatError = require(Package.Logging.formatError)
local Types = require(Package.Types)

local ERROR_INFO_URL = "https://elttob.uk/Fusion/0.3/api-reference/general/errors/#"

local External = {}

local timeCritical = false

External.safetyTimerMultiplier = 1

local updateStepCallbacks = {}
local currentProvider: Types.ExternalProvider? = nil
local lastUpdateStep = 0

function External.setExternalProvider(newProvider: Types.ExternalProvider?): Types.ExternalProvider?
	local oldProvider = currentProvider
	if oldProvider ~= nil then
		oldProvider.stopScheduler()
	end
	currentProvider = newProvider
	if newProvider ~= nil then
		newProvider.startScheduler()
	end
	return oldProvider
end

function External.isTimeCritical(): boolean
	return timeCritical
end

function External.doTaskImmediate(resume: () -> ())
	if currentProvider == nil then
		External.logError("noTaskScheduler")
	else
		currentProvider.doTaskImmediate(resume)
	end
end

function External.doTaskDeferred(resume: () -> ())
	if currentProvider == nil then
		External.logError("noTaskScheduler")
	else
		currentProvider.doTaskDeferred(resume)
	end
end

function External.logError(messageID: string, errObj: Types.Error?, ...: unknown): never
	error(formatError(currentProvider, messageID, errObj, ...), 0)
end

function External.logErrorNonFatal(messageID: string, errObj: Types.Error?, ...: unknown): ()
	local errorString = formatError(currentProvider, messageID, errObj, ...)
	if currentProvider ~= nil then
		currentProvider.logErrorNonFatal(errorString)
	else
		print(errorString)
	end
end

function External.logWarn(messageID: string, ...: unknown): ()
	local errorString = formatError(currentProvider, messageID, debug.traceback(nil, 2), ...)
	if currentProvider ~= nil then
		currentProvider.logWarn(errorString)
	else
		print(errorString)
	end
end

function External.bindToUpdateStep(callback: (now: number) -> ()): () -> ()
	local uniqueIdentifier = {}
	updateStepCallbacks[uniqueIdentifier] = callback
	return function()
		updateStepCallbacks[uniqueIdentifier] = nil
	end
end

function External.performUpdateStep(now: number)
	lastUpdateStep = now
	for _, callback in updateStepCallbacks do
		callback(now)
	end
end

function External.lastUpdateStep()
	return lastUpdateStep
end

return External
