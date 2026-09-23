--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local evaluate = require(Package.Graph.evaluate)

local TERMINATION_TIME = 1

local function change(target: Types.GraphObject): ()
	if target.validity == "busy" then
		return External.logError("infiniteLoop")
	end

	local meaningfullyChanged = evaluate(target, true)
	if not meaningfullyChanged then
		return
	end

	local searchInNow: { Types.GraphObject } = {}
	local searchInNext: { Types.GraphObject } = {}
	local invalidateList: { Types.GraphObject } = {}

	searchInNow[1] = target
	local terminateBy = os.clock() + TERMINATION_TIME * External.safetyTimerMultiplier
	repeat
		if os.clock() > terminateBy then
			return External.logError("infiniteLoop")
		end
		local done = true
		for _, searchTarget in searchInNow do
			for dependent in searchTarget.dependentSet do
				if dependent.validity == "valid" then
					done = false
					table.insert(invalidateList, dependent)
					table.insert(searchInNext, dependent)
				elseif dependent.validity == "busy" then
					return External.logError("infiniteLoop")
				end
			end
		end
		searchInNow, searchInNext = searchInNext, searchInNow
		table.clear(searchInNext)
	until done

	local eagerList: { Types.GraphObject } = {}

	for _, invalidateTarget in invalidateList do
		invalidateTarget.validity = "invalid"
		if invalidateTarget.timeliness == "eager" then
			table.insert(eagerList, invalidateTarget)
		end
	end

	table.sort(eagerList, function(a, b)
		return a.createdAt < b.createdAt
	end)
	for _, eagerTarget in eagerList do
		evaluate(eagerTarget, false)
	end
end

return change
