--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

return Lync.define("Shop", {
	Revive = Lync.packet(Lync.empty()),

	Announce = Lync.packet(Lync.struct({
		Message = Lync.str(0, 120),
	})),
})
