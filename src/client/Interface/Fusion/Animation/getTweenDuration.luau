--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local TweenService = game:GetService("TweenService")

local function getTweenDuration(tweenInfo: TweenInfo): number
	if tweenInfo.RepeatCount <= -1 then
		return math.huge
	end
	local tweenDuration = tweenInfo.DelayTime + tweenInfo.Time
	if tweenInfo.Reverses then
		tweenDuration += tweenInfo.Time
	end
	tweenDuration *= tweenInfo.RepeatCount + 1
	return tweenDuration
end

return getTweenDuration
