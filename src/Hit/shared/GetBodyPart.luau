--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Body = require(ReplicatedStorage.shared.Hit.Body)

export type BodyPart =
	"Head"
	| "HumanoidRootPart"
	| "Left Arm"
	| "Left Leg"
	| "Right Arm"
	| "Right Leg"
	| "Torso"
	| "Other"

const IDS = Body :: { [string]: number }

local GetBodyPart = {}

function GetBodyPart.Get(name: string): number
	return IDS[name] or IDS.Other
end

return GetBodyPart
