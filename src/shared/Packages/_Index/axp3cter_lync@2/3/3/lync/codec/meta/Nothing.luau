--!strict
--!optimize 2

local Base = require(script.Parent.Parent.Base)

local Nothing = {}

Nothing.nothing = Base.constant(nil :: nil)

return table.freeze(Nothing)
