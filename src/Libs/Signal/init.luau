--!nonstrict

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	Block: (self: Signal<T...>) -> (),
	Unblock: (self: Signal<T...>) -> (),
	GetConnectionCount: (self: Signal<T...>) -> number,
	DisconnectAll: (self: Signal<T...>) -> (),
}

export type Api = {
	new: <T...>() -> Signal<T...>,
}

local Signal = {}
Signal.__index = Signal

function Signal.new()
	local self = setmetatable({}, Signal)
	self._connections = {}
	self._blocked = false
	return self
end

function Signal:Connect(callback)
	if type(callback) ~= "function" then
		error("Callback must be a function", 2)
	end

	local connection = {
		Connected = true,
		_callback = callback,
		_signal = self,
	}

	local connectionMeta = {
		__newindex = function(t, k, v)
			if k == "Connected" then
				if not v and rawget(t, "Connected") then
					for i, conn in ipairs(self._connections) do
						if conn == t then
							table.remove(self._connections, i)
							rawset(t, "Connected", false)
							break
						end
					end
				else
					rawset(t, k, v)
				end
			else
				rawset(t, k, v)
			end
		end,
	}

	setmetatable(connection, connectionMeta)
	table.insert(self._connections, connection)

	function connection:Disconnect()
		self.Connected = false
	end

	return connection
end

function Signal:Fire(...)
	if self._blocked then
		return
	end

	local connections = {}
	for _, conn in ipairs(self._connections) do
		table.insert(connections, conn)
	end

	for _, connection in ipairs(connections) do
		if connection.Connected then
			local success, err = pcall(connection._callback, ...)
			if not success then
				warn(`[Signal] a listener errored: {err}`)
			end
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	if not thread then
		error("Wait() must be called from a coroutine", 2)
	end

	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		coroutine.resume(thread, ...)
	end)

	return coroutine.yield()
end

function Signal:Block()
	self._blocked = true
end

function Signal:Unblock()
	self._blocked = false
end

function Signal:GetConnectionCount()
	local count = 0
	for _, conn in ipairs(self._connections) do
		if conn.Connected then
			count = count + 1
		end
	end
	return count
end

function Signal:DisconnectAll()
	for _, conn in ipairs(self._connections) do
		conn.Connected = false
	end
	self._connections = {}
end

setmetatable(Signal, {
	__call = function(self)
		return Signal.new()
	end,
})

return (Signal :: any) :: Api
