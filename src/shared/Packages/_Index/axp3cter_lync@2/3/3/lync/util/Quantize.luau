--!strict
--!optimize 2

local Log = require(script.Parent.Log)

local ceil = math.ceil
local maxN = math.max
local minN = math.min

local writeu8 = buffer.writeu8
local writeu16 = buffer.writeu16
local readu8 = buffer.readu8
local readu16 = buffer.readu16
local band = bit32.band
local bor = bit32.bor
local rshift = bit32.rshift
local lshift = bit32.lshift

local function writeu24(b: buffer, off: number, value: number): ()
	writeu16(b, off, band(value, 0xFFFF))
	writeu8(b, off + 2, band(rshift(value, 16), 0xFF))
end

local function readu24(b: buffer, off: number): number
	return bor(readu16(b, off), lshift(readu8(b, off + 2), 16))
end

local Quantize = {}

function Quantize.setup(
	apiName: string,
	rangeMin: number,
	rangeMax: number,
	precision: number
): (number, (buffer, number, number) -> (), (buffer, number) -> number, number, number, number)
	if rangeMin >= rangeMax then
		Log.error(`{apiName}: min ({rangeMin}) must be < max ({rangeMax})`)
	end
	if precision <= 0 then
		Log.error(`{apiName}: precision must be positive, got {precision}`)
	end

	local delta = rangeMax - rangeMin

	local maxInt = minN(0xFFFFFFFF, maxN(1, ceil(delta / precision)))

	local compBytes: number
	local wfn: (buffer, number, number) -> ()
	local rfn: (buffer, number) -> number
	if maxInt <= 0xFF then
		compBytes, wfn, rfn = 1, buffer.writeu8, buffer.readu8
	elseif maxInt <= 0xFFFF then
		compBytes, wfn, rfn = 2, buffer.writeu16, buffer.readu16
	elseif maxInt <= 0xFFFFFF then
		compBytes, wfn, rfn = 3, writeu24, readu24
	else
		compBytes, wfn, rfn = 4, buffer.writeu32, buffer.readu32
	end

	return compBytes, wfn, rfn, maxInt / delta, delta / maxInt, delta
end

return table.freeze(Quantize)
