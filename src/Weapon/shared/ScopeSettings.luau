--!strict
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Maps = require(ReplicatedStorage.shared.Match.Maps)

const DEFAULT_LIGHTING: Maps.ScopeLighting = {
	LightColor = Color3.new(1.42, 1.43, 1.38),
	Ambient = Color3.new(0.5, 0.47, 0.72),
	HazeColor = Color3.fromRGB(170, 200, 255),
	HazeTransparency = 0.9,
	SkyTop = Color3.fromRGB(30, 100, 235),
	SkyMid = Color3.fromRGB(140, 195, 255),
	SkyBottom = Color3.fromRGB(205, 230, 255),
}

local ScopeSettings = {}

ScopeSettings.ResolutionScale = 1
ScopeSettings.CircleFraction = 0.6
ScopeSettings.PlaneDistance = 1
ScopeSettings.HoleRatio = 0.9
ScopeSettings.RingImage = "rbxassetid://126099400506445"
ScopeSettings.RingInnerRatio = 0.88
ScopeSettings.HaloImage = "rbxassetid://75927697174625"
ScopeSettings.HaloScale = 1.35
ScopeSettings.DefaultHousingColor = Color3.fromRGB(20, 20, 25)
ScopeSettings.StripCount = 4
ScopeSettings.OverlayDisplayOrder = 5
ScopeSettings.TransitionSeconds = 0.2
ScopeSettings.MirrorThreshold = 0.9
ScopeSettings.FallbackLensFraction = 0.12
ScopeSettings.LensResolution = 512
ScopeSettings.LensAnchorName = "ScopeLens"
ScopeSettings.LensDefaultDiameter = 0.45
ScopeSettings.LensDefaultOffset = 0.06
ScopeSettings.LensFadeStart = 0.2118501348963063
ScopeSettings.LensShowFraction = 0.16
ScopeSettings.LensHideFraction = 0.24
ScopeSettings.LensMaskSegments = 24
ScopeSettings.LensMaskOuter = 1.5
ScopeSettings.LensMaskOverlap = 1.05
ScopeSettings.LensMaskGap = 0.004
ScopeSettings.LensMaskTransparency = 0.97
ScopeSettings.LensGap = 0.003
ScopeSettings.LensThickness = 0.002
ScopeSettings.LensFlipDot = 0.35
ScopeSettings.LensCircleFraction = 0.98
ScopeSettings.LensReticleThickness = 1
ScopeSettings.LensReticleDot = 3
ScopeSettings.LensReticleTransparency = 0.15
ScopeSettings.KickUp = 0.035
ScopeSettings.KickSide = 0.012
ScopeSettings.KickFrequency = 8
ScopeSettings.KickDamping = 0.55
ScopeSettings.KickRoll = 2.5
ScopeSettings.KickMax = 2
ScopeSettings.KickEpsilon = 0.0002
ScopeSettings.LensKickScale = 0.4
ScopeSettings.PreloadDelay = 0.5
ScopeSettings.MapName = "Map"
ScopeSettings.MapAttribute = "MapName"
ScopeSettings.RenderBindName = "ScopeController_Render"
ScopeSettings.CharacterTimeout = 5
ScopeSettings.DefaultLighting = DEFAULT_LIGHTING

function ScopeSettings.Lighting(mapName: string?): Maps.ScopeLighting
	const map = if mapName then Maps[mapName] else nil
	return if map and map.ScopeLighting then map.ScopeLighting else DEFAULT_LIGHTING
end

return ScopeSettings
