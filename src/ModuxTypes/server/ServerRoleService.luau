--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Role = "Lobby" | "Match" | "Router"
export type Config = { Map: string, Mode: string, Ranked: boolean, Private: boolean }

export type Public = {
	Config: Config?,
	Error: string?,
	IsReady: boolean,
	Raw: { [string]: any }?,
	Ready: SignalLib.Signal<>,
	Role: Role,
	Setup: (self: Public) -> (),
	GetRole: (self: Public) -> Role,
	GetConfig: (self: Public) -> Config?,
	IsLobby: (self: Public) -> boolean,
	IsMatch: (self: Public) -> boolean,
	IsRouter: (self: Public) -> boolean,
	GetRaw: (self: Public) -> { [string]: any }?,
	OnReady: (self: Public, callback: () -> ()) -> (),
	FetchConfig: (self: Public) -> any?,
	Validate: (self: Public, raw: any) -> (Config?, string?),
	StringAttribute: (self: Public, name: string, fallback: string) -> string,
	Decide: (self: Public) -> (Role, Config?, string?),
	SetMap: (self: Public, mapName: string) -> (),
	Publish: (self: Public) -> (),
	Resolve: (self: Public) -> (),
}

return {}
