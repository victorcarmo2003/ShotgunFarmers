--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

Modux.Start({ DebugLevel = "Medium", Profiling = true })
