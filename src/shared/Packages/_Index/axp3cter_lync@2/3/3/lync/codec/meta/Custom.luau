--!strict
--!optimize 2

local Base = require(script.Parent.Parent.Base)
local Log = require(script.Parent.Parent.Parent.util.Log)
local Types = require(script.Parent.Parent.Parent.Types)

local floor = math.floor

local Custom = {}

function Custom.define<T>(
	size: number,
	writeFn: (b: buffer, offset: number, value: T) -> (),
	readFn: (b: buffer, offset: number) -> T,
	typeCheck: string?
): Types.InternalCodec<T>
	if type(size) ~= "number" or size < 0 or floor(size) ~= size then
		Log.error(`size must be a non-negative integer, got {size}`)
	end

	if size == 0 then
		return Base.constant(nil :: any) :: Types.InternalCodec<T>
	end
	return Base.define(size, writeFn, readFn, if typeCheck then { _typeCheck = typeCheck } else nil)
end

return table.freeze(Custom)
