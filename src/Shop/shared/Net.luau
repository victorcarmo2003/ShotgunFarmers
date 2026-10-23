--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

return Lync.define("Shop", {
	Revive = Lync.packet(Lync.empty()),

	BuySkin = Lync.query(
		Lync.struct({ Id = Lync.str(1, 32) }),
		Lync.struct({ Accepted = Lync.bool(), Reason = Lync.str(0, 120) })
	),

	EquipSkin = Lync.query(
		Lync.struct({ Id = Lync.str(1, 32), Equip = Lync.bool() }),
		Lync.struct({ Accepted = Lync.bool(), Reason = Lync.str(0, 120) })
	),

	RedeemCode = Lync.query(
		Lync.struct({ Code = Lync.str(1, 24) }),
		Lync.struct({ Accepted = Lync.bool(), Reason = Lync.str(0, 120) })
	),

	Announce = Lync.packet(Lync.struct({
		Message = Lync.str(0, 120),
	})),
})
