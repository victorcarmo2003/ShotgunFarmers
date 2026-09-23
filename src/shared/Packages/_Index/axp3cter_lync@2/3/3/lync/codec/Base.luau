--!strict
--!optimize 2

local Log = require(script.Parent.Parent.util.Log)
local Types = require(script.Parent.Parent.Types)

local DEFAULT_MAX = 1048576
local INITIAL_BUF = 1024

local _maxSize = DEFAULT_MAX

local countlz = bit32.countlz
local lshift = bit32.lshift

local function alloc(ch: Types.ChannelState, bytes: number): ()
	if bytes == 0 then
		return
	end

	local needed = ch.cursor + bytes
	if needed <= ch.size then
		return
	end

	if needed > _maxSize then
		local name = ch.currentPacket
		if name then
			Log.error(`packet "{name}" overflowed at {needed}B (max {_maxSize}B)`)
		end
		Log.error(`overflowed at {needed}B (max {_maxSize}B)`)
	end

	local newSize = lshift(1, 32 - countlz(needed - 1))
	local newBuff = buffer.create(newSize)
	buffer.copy(newBuff, 0, ch.buff, 0, ch.cursor)
	ch.buff = newBuff
	ch.size = newSize
end

local Base = {}

Base.INITIAL_BUF = INITIAL_BUF
Base.alloc = alloc

function Base.ensure(ch: Types.ChannelState, n: number): ()
	if ch.cursor + n > ch.size then
		alloc(ch, n)
	end
end

function Base.setMaxSize(bytes: number): ()
	if bytes < INITIAL_BUF then
		Log.error(`bytes ({bytes}) must be >= {INITIAL_BUF}`)
	end
	_maxSize = bytes
end

function Base.reset(): ()
	_maxSize = DEFAULT_MAX
end

function Base.define<T>(
	size: number,
	directWrite: (b: buffer, offset: number, value: T) -> (),
	directRead: (b: buffer, offset: number) -> T,
	meta: { [string]: any }?
): Types.InternalCodec<T>
	local codec: { [string]: any } = {
		_size = size,
		_directWrite = directWrite,
		_directRead = directRead,

		write = function(ch: Types.ChannelState, value: T): ()
			local cursor = ch.cursor
			if cursor + size > ch.size then
				alloc(ch, size)
			end
			directWrite(ch.buff, cursor, value)
			ch.cursor = cursor + size
		end,

		read = function(src: buffer, pos: number, _refs: { Instance }?): (T, number)
			return directRead(src, pos), size
		end,
	}

	if meta then
		for key, val in meta do
			codec[key] = val
		end
	end

	return table.freeze(codec) :: Types.InternalCodec<T>
end

function Base.constant<T>(value: T): Types.InternalCodec<T>
	return table.freeze({
		_size = 0,
		_directWrite = function(_b: buffer, _off: number, _v: T): () end,
		_directRead = function(_b: buffer, _off: number): T
			return value
		end,
		write = function(_ch: Types.ChannelState, _v: T): () end,
		read = function(_src: buffer, _pos: number, _refs: { Instance }?): (T, number)
			return value, 0
		end,
	}) :: Types.InternalCodec<T>
end

return table.freeze(Base)
