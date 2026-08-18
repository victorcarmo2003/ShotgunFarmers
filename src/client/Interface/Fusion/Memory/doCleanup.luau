--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local scopePool = require(Package.Memory.scopePool)
local poisonScope = require(Package.Memory.poisonScope)

local alreadyDestroying: { [Types.Task]: true } = {}

local function doCleanup(task: Types.Task): ()
	if alreadyDestroying[task] then
		return External.logError("destroyedTwice")
	end
	alreadyDestroying[task] = true

	if typeof(task) == "Instance" then
		task:Destroy()
	elseif typeof(task) == "RBXScriptConnection" then
		task:Disconnect()
	elseif typeof(task) == "function" then
		task()
	elseif typeof(task) == "table" then
		local task = (task :: any) :: { Destroy: (...unknown) -> ...unknown?, destroy: (...unknown) -> ...unknown? }

		if typeof(task.destroy) == "function" then
			local task = (task :: any) :: { destroy: (...unknown) -> ...unknown }
			task:destroy()
		elseif typeof(task.Destroy) == "function" then
			local task = (task :: any) :: { Destroy: (...unknown) -> ...unknown }
			task:Destroy()
		elseif task[1] ~= nil then
			local task = task :: { Types.Task }

			for index = #task, 1, -1 do
				doCleanup(task[index])
				task[index] = nil
			end

			if External.isTimeCritical() then
				scopePool.giveIfEmpty(task)
			else
				poisonScope(
					task,
					"`doCleanup()` was previously called on this scope. Ensure you are not reusing scopes after cleanup."
				)
			end
		end
	end

	alreadyDestroying[task] = nil
end

return doCleanup
