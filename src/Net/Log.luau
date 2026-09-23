--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

const SILENCED = {
	["drop.unready"] = true,
}

return function()
	Lync.console:disconnect()

	Lync.onLog(function(_kind: Lync.LogKind, message: string, data: Lync.LogData)
		if SILENCED[data.code :: any] then
			return
		end
		warn(`[lync] {data.file}:{data.line} {message}`)
	end)
end
