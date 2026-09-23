--!strict
--!native

local Base = require(script.Parent.Parent.Base)
local Log = require(script.Parent.Parent.Parent.util.Log)

local writef32 = buffer.writef32
local readf32 = buffer.readf32

local function writeNumberRange(b: buffer, off: number, value: NumberRange): ()
	writef32(b, off, value.Min)
	writef32(b, off + 4, value.Max)
end

local function readNumberRange(b: buffer, off: number): NumberRange
	local minV = readf32(b, off)
	local maxV = readf32(b, off + 4)
	if minV > maxV then
		Log.error(`min ({minV}) > max ({maxV})`)
	end
	return NumberRange.new(minV, maxV)
end

local NumberRangeCodec = {}

NumberRangeCodec.numberRange = Base.define(8, writeNumberRange, readNumberRange, {
	_typeCheck = "NumberRange",
})

return table.freeze(NumberRangeCodec)
