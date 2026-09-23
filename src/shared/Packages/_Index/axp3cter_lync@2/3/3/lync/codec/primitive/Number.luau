--!strict
--!optimize 2

local Base = require(script.Parent.Parent.Base)

local F32_SCRATCH = buffer.create(4)

local Number = {}

Number.f32 = Base.define(4, buffer.writef32, buffer.readf32, { _typeCheck = "number" })
Number.f64 = Base.define(8, buffer.writef64, buffer.readf64, { _typeCheck = "number" })

Number._f32Scratch = F32_SCRATCH

return table.freeze(Number)
