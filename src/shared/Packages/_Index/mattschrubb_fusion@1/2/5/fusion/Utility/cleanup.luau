--!strict

local function cleanupOne(task: any)
	local taskType = typeof(task)

	if taskType == "Instance" then
		task:Destroy()
	elseif taskType == "RBXScriptConnection" then
		task:Disconnect()
	elseif taskType == "function" then
		task()
	elseif taskType == "table" then
		if typeof(task.destroy) == "function" then
			task:destroy()
		elseif typeof(task.Destroy) == "function" then
			task:Destroy()
		elseif task[1] ~= nil then
			for _, subtask in ipairs(task) do
				cleanupOne(subtask)
			end
		end
	end
end

local function cleanup(...: any)
	for index = 1, select("#", ...) do
		cleanupOne(select(index, ...))
	end
end

return cleanup
