--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent
local Types = require(Package.Types)

local currentProvider: Types.ExternalDebugger? = nil
local lastUpdateStep = 0

local Debugger = {}

function Debugger.setDebugger(newProvider: Types.ExternalDebugger?): Types.ExternalDebugger?
	local oldProvider = currentProvider
	if oldProvider ~= nil then
		oldProvider.stopDebugging()
	end
	currentProvider = newProvider
	if newProvider ~= nil then
		newProvider.startDebugging()
	end
	return oldProvider
end

function Debugger.trackScope(scope: Types.Scope<unknown>): ()
	if currentProvider == nil then
		return
	end
	currentProvider.trackScope(scope)
end

function Debugger.untrackScope(scope: Types.Scope<unknown>): ()
	if currentProvider == nil then
		return
	end
	currentProvider.trackScope(scope)
end

return Debugger
