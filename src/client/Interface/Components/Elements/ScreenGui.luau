local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local TableMerge = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.TableMerge)

export type screenGuiProp = {
	Archivable: boolean,
	DisplayOrder: number,
	Enabled: boolean,
	IgnoreGuiInset: boolean,
	Name: string,
	Parent: string?,
	ResetOnSpawn: boolean,
	ZIndexBehavior: string,
} & {any}

local defaultProps: screenGuiProp = {
	Archivable = true,
	DisplayOrder = 0,
	Enabled = true,
	IgnoreGuiInset = true,
	Name = "ScreenGui",
	ResetOnSpawn = true,
	ZIndexBehavior = "Sibling",
}

return function(scope: Fusion.Scope, props: screenGuiProp): ScreenGui
	return scope:New("ScreenGui")(TableMerge(defaultProps, props)) :: ScreenGui
end
