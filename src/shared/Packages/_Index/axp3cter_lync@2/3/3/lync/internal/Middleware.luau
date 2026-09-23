--!strict
--!optimize 2

local Signal = require(script.Parent.Parent.api.Signal)
local Types = require(script.Parent.Parent.Types)

local _sendSignal = Signal.create()
local _receiveSignal = Signal.create()
local _dropSignal = Signal.create()

local STATE_DISCONNECTED = 0

local function runChain(signal: { _count: number, _entries: { any } }, value: any, name: string, player: Player?): any
	local count = signal._count
	if count == 0 then
		return value
	end

	local entries = signal._entries
	local snapshot = table.create(count)
	table.move(entries, 1, count, 1, snapshot)

	local result = value
	for i = 1, count do
		local entry = snapshot[i]
		if entry._state ~= STATE_DISCONNECTED then
			local returned = entry.fn(result, name, player)

			if returned ~= nil then
				result = returned
			end
		end
	end
	return result
end

local Middleware = {}

function Middleware.onSend(fn: (data: any, name: string, player: Player?) -> any): Types.Connection
	return _sendSignal:connect(fn)
end

function Middleware.onReceive(fn: (data: any, name: string, player: Player?) -> any): Types.Connection
	return _receiveSignal:connect(fn)
end

function Middleware.onDrop(fn: (player: Player, reason: string, name: string, data: any?) -> ()): Types.Connection
	return _dropSignal:connect(fn)
end

function Middleware.runSend(data: any, name: string, player: Player?): any
	return runChain(_sendSignal, data, name, player)
end

function Middleware.runReceive(data: any, name: string, player: Player?): any
	return runChain(_receiveSignal, data, name, player)
end

function Middleware.fireDrop(player: Player, reason: string, name: string, data: any?): ()
	_dropSignal:fireSync(player, reason, name, data)
end

function Middleware.hasSendHooks(): boolean
	return _sendSignal:hasListeners()
end

function Middleware.hasReceiveHooks(): boolean
	return _receiveSignal:hasListeners()
end

function Middleware.reset(): ()
	_sendSignal = Signal.create()
	_receiveSignal = Signal.create()
	_dropSignal = Signal.create()
end

return table.freeze(Middleware)
