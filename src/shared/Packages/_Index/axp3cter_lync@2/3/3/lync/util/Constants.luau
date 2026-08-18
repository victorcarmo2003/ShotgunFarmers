--!strict
--!optimize 2

local Constants = {}

Constants.U8_MAX = 0xFF
Constants.U16_MAX = 0xFFFF
Constants.U32_MAX = 0xFFFFFFFF

Constants.I8_MIN = -0x80
Constants.I8_MAX = 0x7F
Constants.I16_MIN = -0x8000
Constants.I16_MAX = 0x7FFF
Constants.I32_MIN = -0x80000000
Constants.I32_MAX = 0x7FFFFFFF

Constants.FRAME_MSB = 0x80
Constants.FRAME_ID_MASK = 0x7F

Constants.MAX_BATCH_ITEMS = 0xFFFF

return table.freeze(Constants)
