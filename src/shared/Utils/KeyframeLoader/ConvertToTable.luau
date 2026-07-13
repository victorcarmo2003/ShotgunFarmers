local InsertService = game:GetService("InsertService")
local KeyboardService = game:GetService("KeyboardService")
local MarketplaceService = game:GetService("MarketplaceService")

local __EasingStyles__ = Enum.EasingStyle
local __EasingDirections__ = Enum.EasingDirection
local __Enum__PoseEasingStyle__ = #"Enum.PoseEasingStyle."
local __Enum__PoseEasingDirection__ = #"Enum.PoseEasingDirection."
local table_create = table.create
local function EasingStyleFix(style:Enum.PoseEasingStyle):Enum.EasingStyle
	style = string.sub(tostring(style),__Enum__PoseEasingStyle__+1,-1)
	return __EasingStyles__[style]
end
local function EasingDirectionFix(style:Enum.PoseEasingDirection):Enum.EasingDirection
	style = string.sub(tostring(style),__Enum__PoseEasingDirection__+1,-1)
	return __EasingDirections__[style]
end
local regularTBL = table_create(0)

return function(AnimationInstance:KeyframeSequence): ({},boolean,Enum.AnimationPriority)
	if AnimationInstance==nil then error(`AnimationInstance can\'t be nil`) end
	if typeof(AnimationInstance)~="Instance" then return regularTBL end
	local KeyFrames = AnimationInstance:GetKeyframes()
	--KeyFrames
	local Sequance = table_create(#KeyFrames)
	for i,v:Keyframe in KeyFrames do
		local Class = {}
		local ClassData = {}
		Class["Time"] = v.Time
		local Poses = v:GetDescendants()
		--Posses
		for i_,v_:KeyframeMarker | Pose in Poses do
			if v_:IsA("KeyframeMarker") then
				if Class["Events"] == nil then
					Class["Events"] = {}
				end
				
				local Marker = {}
				Marker["Name"] = v_.Name
				Marker["Value"] = v_.Value
				table.insert(Class["Events"],Marker)
				continue
			end
			if v_:IsA("Pose") then
				if v_.Weight == 0 then continue end
				local Pose = {}
				Pose["CFrame"] = v_.CFrame
				Pose["EasingStyle"] = EasingStyleFix(v_.EasingStyle)
				Pose["EasingDirection"] = EasingDirectionFix(v_.EasingDirection)
				Pose["Weight"] = v_.Weight or 0
				ClassData[v_.Name] = Pose
				continue
			end
			
			
			
		end
		
		
		Class["Data"] = ClassData
		table.insert(Sequance,Class)
	end
	table.sort(Sequance,function(a,b)
		return a.Time < b.Time
	end)
	
	return Sequance,AnimationInstance.Loop,AnimationInstance.Priority
end
