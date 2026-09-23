--!strict
--!optimize 2

local _silent = false

local PREFIX = "[Lync]"

local function format(message: string): string
	local source, line, name = debug.info(3, "sln")
	local file = source:match("([^.]+)%.spec$") or source:match("[^./\\]+$") or source
	if name and name ~= "" then
		return `{PREFIX} {file}:{line} ({name}) {message}`
	end
	return `{PREFIX} {file}:{line} {message}`
end

local Log = {}

function Log.warn(message: string): ()
	if not _silent then
		warn(format(message))
	end
end

function Log.error(message: string): never
	error(format(message), 2)
end

function Log.assert<T>(cond: T, message: string): T
	return assert(cond, format(message))
end

function Log.setSilent(silent: boolean): ()
	_silent = silent
end

function Log.reset(): ()
	_silent = false
end

return table.freeze(Log)
