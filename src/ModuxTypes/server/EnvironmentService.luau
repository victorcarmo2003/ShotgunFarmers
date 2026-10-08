--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

type MatchConfig = { Map: string, Mode: string }

export type Public = {
	IsReady: boolean,
	MapChanged: SignalLib.Signal<string>,
	Ready: SignalLib.Signal<>,
	Root: Instance?,
	Setup: (self: Public) -> (),
	GetRoot: (self: Public) -> Instance?,
	OnReady: (self: Public, callback: () -> ()) -> (),
	GetFFASpawns: (self: Public) -> { BasePart },
	GetTeamSpawn: (self: Public, teamName: string) -> BasePart?,
	GetLobbySlot: (self: Public, index: number) -> BasePart?,
	GetLobbyCamera: (self: Public) -> BasePart?,
	ValidateMap: (self: Public, mapName: string, source: Instance?, problems: { string }) -> (),
	Validate: (self: Public) -> (),
	ApplyLighting: (self: Public, presetName: string) -> (),
	BuildBoundary: (self: Public, root: Instance, mapName: string) -> (),
	InstantiateMap: (self: Public, mapName: string) -> (Instance, string),
	Instantiate: (self: Public, role: string, config: MatchConfig?) -> (Instance, string),
	Mount: (self: Public, root: Instance, lightingName: string) -> (),
	Load: (self: Public, role: string, config: MatchConfig?) -> (),
	SwapMap: (self: Public, mapName: string) -> boolean,
}

return {}
