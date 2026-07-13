local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local TableMerge = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.TableMerge)

export type surfaceGuiProp = {
	Archivable: boolean,
	AlwaysOnTop: boolean,
	Brightness: number,
	CanvasSize: Vector2?,
	ClipsDescendants: boolean,
	Enabled: boolean,
	LightInfluence: number,
	PixelsPerStud: number,
	SizingMode: Enum.SurfaceGuiSizingMode,
	ToolPunchThroughDistance: number,
	ZOffset: number,
	Active: boolean?,
	Adornee: Instance?,
	Face: Enum.NormalId?,
	Name: string,
	Parent: Instance?,
	ResetOnSpawn: boolean,
	ZIndexBehavior: string,
} & { any }

local defaultProps: surfaceGuiProp = {
	Archivable = true,
	AlwaysOnTop = true,
	Brightness = 1,
	ClipsDescendants = false,
	Enabled = true,
	LightInfluence = 0,
	PixelsPerStud = 300,
	Face = Enum.NormalId.Back,
	SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
	ToolPunchThroughDistance = 0,
	ZOffset = 0,
	Name = "SurfaceGui",
	ResetOnSpawn = true,
	ZIndexBehavior = "Sibling",
}

return function(scope: Fusion.Scope, props: surfaceGuiProp): SurfaceGui
	return scope:New("SurfaceGui")(TableMerge(defaultProps, props)) :: SurfaceGui
end
