--!strict
--!native

local Base = require(script.Parent.Parent.Base)
local Constants = require(script.Parent.Parent.Parent.util.Constants)
local Log = require(script.Parent.Parent.Parent.util.Log)
local Types = require(script.Parent.Parent.Parent.Types)

local INLINE_MAX = 0xBF
local TWO_TAG = 0xC0
local TWO_END = 0xDF
local TWO_MASK = 0x1F
local THREE_TAG = 0xE0
local THREE_END = 0xEF
local THREE_MASK = 0x0F
local FIVE_TAG = 0xF0
local TWO_MAX = 8383
local THREE_MAX = 1056959
local TWO_BIAS = 192
local THREE_BIAS = 8384

local U8_MAX = Constants.U8_MAX
local U16_MAX = Constants.U16_MAX
local U32_MAX = Constants.U32_MAX

local ensure = Base.ensure
local band = bit32.band
local bor = bit32.bor
local rshift = bit32.rshift
local writeu8 = buffer.writeu8
local writeu16 = buffer.writeu16
local writeu32 = buffer.writeu32
local readu8 = buffer.readu8
local readu16 = buffer.readu16
local readu32 = buffer.readu32

local Varint = {}

Varint.INLINE_MAX = INLINE_MAX

function Varint.length(value: number): number
	if value <= INLINE_MAX then
		return 1
	elseif value <= TWO_MAX then
		return 2
	elseif value <= THREE_MAX then
		return 3
	end
	return 5
end

function Varint.write(ch: Types.ChannelState, value: number): ()
	if value < 0 or value > U32_MAX or value % 1 ~= 0 then
		Log.error(`value must be an integer in [0, {U32_MAX}], got {value}`)
	end

	if value <= INLINE_MAX then
		ensure(ch, 1)
		local cursor = ch.cursor
		writeu8(ch.buff, cursor, value)
		ch.cursor = cursor + 1
		return
	end

	if value <= TWO_MAX then
		ensure(ch, 2)
		local cursor = ch.cursor
		local adjusted = value - TWO_BIAS
		local b = ch.buff
		writeu8(b, cursor, bor(TWO_TAG, rshift(adjusted, 8)))
		writeu8(b, cursor + 1, band(adjusted, U8_MAX))
		ch.cursor = cursor + 2
		return
	end

	if value <= THREE_MAX then
		ensure(ch, 3)
		local cursor = ch.cursor
		local adjusted = value - THREE_BIAS
		local b = ch.buff
		writeu8(b, cursor, bor(THREE_TAG, rshift(adjusted, 16)))
		writeu16(b, cursor + 1, band(adjusted, U16_MAX))
		ch.cursor = cursor + 3
		return
	end

	ensure(ch, 5)
	local cursor = ch.cursor
	local b = ch.buff
	writeu8(b, cursor, FIVE_TAG)
	writeu32(b, cursor + 1, value)
	ch.cursor = cursor + 5
end

function Varint.read(src: buffer, pos: number): (number, number)
	local available = buffer.len(src) - pos
	if available < 1 then
		return 0, 0
	end
	local b0 = readu8(src, pos)
	if b0 <= INLINE_MAX then
		return b0, 1
	end
	if b0 <= TWO_END then
		if available < 2 then
			return 0, 0
		end
		return band(b0, TWO_MASK) * 256 + readu8(src, pos + 1) + TWO_BIAS, 2
	end
	if b0 <= THREE_END then
		if available < 3 then
			return 0, 0
		end
		return band(b0, THREE_MASK) * 65536 + readu16(src, pos + 1) + THREE_BIAS, 3
	end
	if available < 5 then
		return 0, 0
	end
	return readu32(src, pos + 1), 5
end

function Varint.writeInline(ch: Types.ChannelState, value: number): ()
	ensure(ch, 1)
	local cursor = ch.cursor
	writeu8(ch.buff, cursor, value)
	ch.cursor = cursor + 1
end

function Varint.readLengthPrefix(src: buffer, pos: number): (number, number)
	if buffer.len(src) - pos < 1 then
		return 0, 0
	end
	local b0 = readu8(src, pos)
	if b0 <= INLINE_MAX then
		return b0, 1
	end
	return Varint.read(src, pos)
end

return table.freeze(Varint)
