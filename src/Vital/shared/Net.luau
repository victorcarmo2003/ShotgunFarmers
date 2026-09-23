--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

return Lync.define("Vital", {
	Vitals = Lync.replicate(Lync.struct({
		Health = Lync.int(0, 100),
		Armor = Lync.int(0, 100),
		Stamina = Lync.int(0, 100),
	})),
})
