--!strict

local Package = script.Parent.Parent
local logError = require(Package.Logging.logError)

type table = { [any]: any }

local function restrictRead(tableName: string, strictTable: table): table
	local metatable = getmetatable(strictTable :: any)

	if metatable == nil then
		metatable = {}
		setmetatable(strictTable, metatable)
	end

	function metatable:__index(memberName)
		logError("strictReadError", nil, tostring(memberName), tableName)
	end

	return strictTable
end

return restrictRead
