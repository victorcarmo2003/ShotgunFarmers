--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

return Lync.define("Options", {
	State = Lync.packet(Lync.struct({
		Settings = Lync.map(Lync.str(1, 32), Lync.f32(), 0, 64),
		Keybinds = Lync.map(Lync.str(1, 32), Lync.str(1, 32), 0, 64),
	})),

	SetSetting = Lync.packet(Lync.struct({
		Id = Lync.str(1, 32),
		Value = Lync.f32(),
	})),

	SetKeybind = Lync.packet(Lync.struct({
		Id = Lync.str(1, 32),
		Key = Lync.str(1, 32),
	})),
})
