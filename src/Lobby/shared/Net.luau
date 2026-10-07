--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

return Lync.define("Lobby", {
	Online = Lync.packet(Lync.int(0, 10000000)),
})
