--@Yarik_superpro
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local table_create = table.create
local cframe_zero = CFrame.new(0,0,0)


local PriorityTable = require(script:WaitForChild("Priority"))
local ConvertToTable = require(script:WaitForChild("ConvertToTable"))
local AutoGetMotor6D = require(script:WaitForChild("AutoGetMotor6D"))
local GetFrameInBetween = require(script:WaitForChild("GetFrameInBetween"))
local GroupTamplate = script:WaitForChild("GroupTamplate")
local ReturnableTypes = require(script:WaitForChild("ReturnableTypes"))

type AnimType = ReturnableTypes.AnimationSequance
type SettingsType = ReturnableTypes.Setting
type Motor6DorBones = "Motor6D"|"Bone"|nil
export type AT = AnimType



local function ReturnValuesThatFound(tab,val)
	local a = {}
	for i,v in tab do
		if v==val then
			table.insert(a,i)
		end
	end
	return a
end
local function ReturnFadingAnimations(Group:{})
	local tab = {}
	for i,v in Group["i"] do
		if Group["i"][i].FadingAnimation == true then
			table.insert(tab,i)
		end
	end
	return tab
end

local function SafeCallEvent(event,...)
	if event==nil or typeof(event)~="Instance"or not event:IsA("BindableEvent") then return end
	event:Fire(...)
end

local function CallEvents(Animation,Call:BindableEvent,Time:number,MarkersUsed)
	if Call == nil or typeof(Call)~="Instance"or not Call:IsA("BindableEvent") then return end
	if Time == nil or type(Time)~="number" then return end
	local Data = nil
	for i,v in Animation do
		if v.Time <= Time and v.Events ~= nil and MarkersUsed[""..i..""]==nil then
			if i==#Animation then
				Data = i
			elseif	Animation[i+1].Time >= Time then
				Data = i
			else
				continue
			end
			
		else
			continue
		end
	end
	if Data ~= nil then
		for i,v in Animation[Data]["Events"] do
			Call:Fire("KeyframeMarker",v["Name"],v["Value"])
		end
	end
	return Data
end

local function TransformMotor6D(MotorListm,MotorName:string,Cframe:CFrame)
	if MotorListm==nil or type(MotorListm)~="table" then return end
	local a = MotorListm[MotorName]
	if a == nil then return end
	if typeof(a)=="Instance" and a:IsA("Motor6D") or a:IsA("Bone") then
		a.Transform = Cframe
	end
end
local function ilerp(value:number, minimum:number, maximum:number):number
	if value == nil or minimum ==nil or maximum == nil then warn("Empty") return 0 end
	if type(value)~="number"or type(minimum)~="number"or type(maximum)~="number" then warn("Must be a number") return 0 end 
	local ret = (value - minimum) / (maximum - minimum)
	if minimum==maximum then ret = 1 end
	return ret
end


local IsClient = true
local UpdateEachFrame = RunService.PreSimulation
--if not RunService:IsClient() then
--	IsClient = false
--	UpdateEachFrame = RunService.Stepped
--end

local function GetPlayingTracks(self)
	local Group = self["Group"]
	local list:any = {}
	if Group == nil then return nil end
	for i,v in Group["i"] do
		if v["IsPlaying"]==true then
			list[i]=i
		end
	end
	return list
end
local function TableLen(e):number
	local ea = 0
	for i,v in e do
		ea += 1
	end
	return ea
end
local function FramesWhereJointAppeared(JointName,KeyFrameTable)
	local ret = {}
	for i,v in KeyFrameTable do
		if v.Data[JointName]~=nil then
			ret[i] = i
		end
	end
	return ret
end


local function GetFinalPositionOfJointTime(JointName:string,Time:number,KeyFrameTable:any,Animate:any,CurrentWeight:number)
	if Animate == nil then Animate = true end
	local returned = nil
	local weight = 1
	local seen_in = FramesWhereJointAppeared(JointName,KeyFrameTable)
	local FirstIndex = 1
	local SecondIndex = 1
	for i,v in seen_in do
		local a = KeyFrameTable[i]
		if a.Time <= Time then
			FirstIndex = i
			SecondIndex = i
		else
			SecondIndex = i
			break
		end
	end
	local FirstFrame,SecondFrame = KeyFrameTable[FirstIndex],KeyFrameTable[SecondIndex]
	weight = SecondFrame["Data"][JointName]["Weight"]
	--if Time > SecondFrame.Time then return nil end
	if Animate == nil or Animate == "Animate" then
		local LinearLerpValue = ilerp(Time,FirstFrame.Time,SecondFrame.Time)
		local JointDataFirst,JointDataSecond = FirstFrame["Data"][JointName],SecondFrame["Data"][JointName]
		local EasingLerp = TweenService:GetValue(LinearLerpValue,JointDataSecond.EasingStyle,JointDataSecond.EasingDirection)
		local JointCFrame_first:CFrame,JointCFrame_second:CFrame = JointDataFirst["CFrame"],JointDataSecond["CFrame"]
		local JointWeight_first:CFrame,JointWeight_second:CFrame = JointDataFirst["Weight"],JointDataSecond["Weight"]
		if JointWeight_first<1 then
			JointCFrame_first=JointCFrame_first:Lerp(cframe_zero,ilerp(JointWeight_first,0,1))
		end
		if JointWeight_second<1 then
			JointCFrame_second=JointCFrame_second:Lerp(cframe_zero,ilerp(JointWeight_second,0,1))
		end
		
		returned = JointCFrame_first:Lerp(JointCFrame_second,EasingLerp)
	else
		if Animate == "First" then
			returned = FirstFrame["Data"][JointName]["CFrame"]
		else
			returned = SecondFrame["Data"][JointName]["CFrame"]
		end
		
	end
	if CurrentWeight == nil then CurrentWeight = 1 end
	if CurrentWeight>1 then
		CurrentWeight = 1
	elseif CurrentWeight <0 then
		CurrentWeight = 0
	end
	
	returned = cframe_zero:Lerp(returned,CurrentWeight)

	
	
	return returned,weight
end

local function ResetMotors6D(motorlist,self)
	local group = self["Group"]
	if group == nil then
		for i,v in motorlist do
			TransformMotor6D(motorlist,i,cframe_zero)
		end
	else
		local tracks = TableLen(GetPlayingTracks(self))
		if tracks == 0 then
			for i,v in motorlist do
				TransformMotor6D(motorlist,i,cframe_zero)
			end
		end
	end
end


--==========================================================

local module = {}
module.__index = module



function module.CreateModuleGroup()
	return GroupTamplate:Clone()
end


local NotPassedSettings = {
	["StartsAt"] = 0;
	["CanTransformMotor6D"] = true;--Don't touch
	["Animate"] = "Animate";-- "Animate"|"First"|"Last"|nil -- Teleport to next keyframes straight if false 1 - first 2 - second
	["UpsyncThePlaying"] = "Default";--[[ "Default"|"Ramp"|"SpeedUp"|nil
	1 a little speed up ramp and then return to normal speed with now synced animation
	2 increase speed in all animation to sync ]]	
}
local MethodLockEditingTable = {
	__newindex = function(table,index,value)
		local Found:boolean = false
		for i,v in NotPassedSettings do
			if index==i then
				Found = true
				break
			end
		end
		if Found~=true then
			warn("Table is edit only!")
			return nil
		end
		return value
	end,
}


module.AutoGetMotor6D = AutoGetMotor6D
module.KeyFrameSequanceToTable = ConvertToTable

function module.new(Motor6DTable:Model|{},KeyFrameSequance:KeyframeSequence|{},AnimationGroup:ModuleScript?,Settings:SettingsType,Motor6DorBone:Motor6DorBones):AnimType
	local self = setmetatable({} :: AnimType,module)
	self["Looped"] = false;
	self["TimePosition"] = 0;
	self["IsPlaying"] = false;
	self["Speed"] = 1;
	self["Weight"] = 1;
	self["WeightCurrent"] = 1;
	self["WeightTarget"] = 0;
	self["Priority"] = Enum.AnimationPriority.Core;
	self["Name"] = "";
	if typeof(Motor6DTable)=="Instance" and Motor6DTable:IsA("Model") then Motor6DTable = AutoGetMotor6D(Motor6DTable,Motor6DorBone) end
	self["Motor6D"] = Motor6DTable
	if KeyFrameSequance==nil then
		error(`Parameter \"KeyFrameSequance\" cannot be nil`)
	end
	
	if typeof(KeyFrameSequance)=="Instance" and KeyFrameSequance:IsA("KeyframeSequence") then
		local Animation,Looped,Priority = ConvertToTable(KeyFrameSequance)
		self.Animation = Animation
		self["Priority"] = Priority
		self["Looped"] = Looped
		
	elseif typeof(KeyFrameSequance)=="table" then
		self.Animation = KeyFrameSequance
	else
		error(`Unvalid format for \"KeyFrameSequance\",format sent: {typeof(KeyFrameSequance)}`)
	end

	if Settings == nil then
		self.Settings = NotPassedSettings
	end
	self["Length"] = self.Animation[#self.Animation].Time
	
	--Add not passed settings
	for i,v in NotPassedSettings do
		if self.Settings[i] == nil then
			self.Settings[i] = v
		end
	end
	local event = Instance.new("BindableEvent")
	local EndedEvent,StoppedEvent,DidLoopEvent = Instance.new("BindableEvent"),Instance.new("BindableEvent"),Instance.new("BindableEvent")
	
	self["_fireEnded"] = EndedEvent
	self["_fireStopped"] = StoppedEvent
	self["_fireDidLoop"] = DidLoopEvent
	self["_fireEvent"] = event
	self.Ended = EndedEvent.Event
	self.Stopped = StoppedEvent.Event
	self.DidLoop = DidLoopEvent.Event
	self.Event = event.Event
	
	setmetatable(self.Settings,MethodLockEditingTable)
	
	if AnimationGroup ~= nil and typeof(AnimationGroup) == "Instance" and AnimationGroup:IsA("ModuleScript") then
		self["Group"] = require(AnimationGroup)
		local AnimationGroup:{["i"]:{}} = self["Group"]
		local id = HttpService:GenerateGUID(false)
		local foundDupe = false
		--Specially for paranoids so your 1 in a 131231414B chance not heppens
		for i,v in AnimationGroup["i"] do
			if id == i then
				foundDupe = true
			end
		end
		repeat
			id = HttpService:GenerateGUID(false)
			foundDupe = false
			for i,v in AnimationGroup["i"] do
				if id == i then
					foundDupe = true
				end
			end
		until foundDupe == false
		
		self.DataID = id
		
		AnimationGroup["i"][id] = self
		
		
		return AnimationGroup["i"][id],id
	else
		return self
	end	
end



function module:StopFading()
	self.FadeDelta = nil
	self.FadeMax = nil
	self.FadeTime = nil
	self.FadingAnimation = nil
	self._tempLoop = nil
	self.Settings.CanTransformMotor6D = false
end
function module:Cancel(DontResetMotor6D:boolean)
	local save = self.Settings.CurrentlyAt
	self.Settings.CanTransformMotor6D = false
	self["IsPlaying"] = false
	self["TimePosition"] = 0
	self:StopFading()
	--stop
	if self["_Connection"]~=nil and typeof(self["_Connection"])=="RBXScriptConnection" then
		self["_Connection"]:Disconnect()
	end
	if self.Task~=nil and typeof(self.Task)=="thread" then
		coroutine.close(self.Task)
	end
	if DontResetMotor6D~=true and self["Group"] then
		ResetMotors6D(self["Motor6D"],self)
	end
	SafeCallEvent(self["_fireEvent"],"MarkerSignal","Canceled")
	return save
end
function module:Freeze()
	self["IsPlaying"] = false
	SafeCallEvent(self["_fireEvent"],"MarkerSignal","Frozen")
	self.Settings.CanTransformMotor6D = true
	return self.Settings.CurrentlyAt
end
function module:UnFreeze()
	self["IsPlaying"] = true
	SafeCallEvent(self["_fireEvent"],"MarkerSignal","UnFrozen")
	if self.Group ~= nil then
		for i,v in self.Group["i"] do
			if self["Group"]["i"][i].Settings.CanTransformMotor6D == true then
			self["Group"]["i"][i].Settings.CanTransformMotor6D = false
			end
		end
	end
	self.Settings.CanTransformMotor6D = true
end

function module:Destroy()
	self:Cancel()
	if self.Group then
		self.Group[self.DataID] = nil
	end
	self = nil
end

function module:AdjustWeight(weight: number,fadeTime: number)
	self["Weight"] = weight
	self["WeightCurrent"] = weight;
	self["WeightTarget"] = 0;
	self.FadeMax = fadeTime
	self.FadeTime = fadeTime
end


function module:Stop(FadeTime:number)
	if self.FadingAnimation == true or self["IsPlaying"] ~= true then return end
	self["_tempLoop"] = true
	SafeCallEvent(self["_fireStopped"])
	if FadeTime~=nil then
		if type(FadeTime)~="number" then FadeTime = 0.15 end
		if self.FadeTime == nil or self.FadeTime == 0 then
			self.FadeTime = FadeTime
		end
		self["WeightCurrent"] = self["Weight"];
		self["WeightTarget"] = 0;
		self["_tempLoop"] = true
		self.FadingAnimation = true
		self["FadeMax"]=self.FadeTime
		self["FadeDelta"] = self["TimePosition"]
		self["IsPlaying"] = true
	else
		self["IsPlaying"] = false
		self.Settings.CanTransformMotor6D = false
	end

	
end

function module:Play(FadeTime:number,Weight:number,TimeStamp:number,Speed:number)
	self["WeightCurrent"] = Weight
	self["Weight"] = Weight
	self:StopFading()
	if self["_Connection"]~=nil and typeof(self["_Connection"])=="RBXScriptConnection" then
		self["_Connection"]:Disconnect()
	end
	if self.Task~=nil and typeof(self.Task)=="thread" then
		coroutine.close(self.Task)
	end

	
	if self["_Connection"]~=nil and typeof(self["_Connection"])=="RBXScriptConnection" then
		self["_Connection"]:Disconnect()
	end
	if self.Task~=nil and typeof(self.Task)=="thread" then
		coroutine.close(self.Task)
	end
	if FadeTime ~= nil and type(FadeTime)=="number" then
		self["FadeTime"] = FadeTime
		self["FadeMax"] = FadeTime
	end
	

	local IsGroup = false
	local MadeOneLoop = false
	local FirstFramePlayed = true
	local UsedIt = false
	local UsedEventMarkers = {}
	if TimeStamp ~= nil and type(TimeStamp)=="number" then
		if TimeStamp>self["Length"] then
			TimeStamp = self["Length"]
		end
		self["TimePosition"] = TimeStamp
	end
	
	if self["Group"] ~= nil and typeof(self["Group"]) == "table" then
		if self["Group"]["i"][self.DataID]==self then
			--Group Passed
			IsGroup = true
			for i,v in self["Group"]["i"] do
				v.Settings.CanTransformMotor6D = false
			end
			self.Settings.CanTransformMotor6D = true;
		end
	end
	
	self["_debugSpeed"] = nil
	SafeCallEvent(self["_fireEvent"],"MarkerSignal","Play")
	self["Task"] = coroutine.create(function()
		self["IsPlaying"] = true
		local connection:RBXScriptConnection
		connection = UpdateEachFrame:Connect(function(delta1:number,delta2:number)
			if self["IsPlaying"] == false then return end
			if self["FadeTime"]~= nil and self["FadeTime"] <= 0 then
				self["FadeTime"] = 0
			end
			--Deltatime
			local delta,trueDelta = delta1,delta1
			--if IsClient then
				--delta = delta1
				--trueDelta = delta1
			--end
			
			if MadeOneLoop == false and TimeStamp~=nil then
				local Lengh = self["Length"]-self.Settings.StartsAt
				local OneTenth = Lengh/10
				local TargetGoal = TimeStamp+OneTenth
				if self.Settings["UpsyncThePlaying"] == "Ramp" then
					--Speed up ramp
		
					
				if Lengh-TimeStamp>OneTenth then
						if UsedIt == false and self["_debugSpeed"]==nil then
						UsedIt = 1
						local a = TargetGoal/(TargetGoal-TimeStamp)
							self["TimePosition"] = 0
						self["_debugSpeed"] = a
						elseif UsedIt == 1 and self["TimePosition"]>=TargetGoal then
							UsedIt = 2
							self["_debugSpeed"] = nil
					end
					else
						self["_debugSpeed"] = Lengh/(Lengh-TimeStamp)
				end
				elseif self.Settings["UpsyncThePlaying"] == "SpeedUp" and self["_debugSpeed"]==nil then
					--constant speedup
					if self["TimePosition"]==TimeStamp and UsedIt == false then
						UsedIt = true
						local a = Lengh/(Lengh-TimeStamp)
						self["TimePosition"] = 0
						self["_debugSpeed"] = a
					end
			end
			end
			
			
			if self["Speed"] ~= 1 then
				delta *=self["Speed"]
			end
			if self["_debugSpeed"]~=nil then
				delta *=self["_debugSpeed"]
			end
			

			local CurrentlyAtDelta = self["TimePosition"]+delta
			local OkTest = CallEvents(self.Animation,self["_fireEvent"],CurrentlyAtDelta,UsedEventMarkers)
			if OkTest ~= nil then
				UsedEventMarkers = {}
				UsedEventMarkers[`{OkTest}`] = OkTest
			end
			
			---------- Reverse Play
			if CurrentlyAtDelta < 0 then
				CurrentlyAtDelta = self["Length"]-math.abs(CurrentlyAtDelta)
				self["TimePosition"] = CurrentlyAtDelta
				self["_debugSpeed"] = nil
				MadeOneLoop = true
				if self.FadingAnimation ~= true then
					if self["Looped"] == true or self["_tempLoop"]==true then
						SafeCallEvent(self["_fireDidLoop"],false)
						self["TimePosition"] = self.Settings.StartsAt
						UsedEventMarkers = {}
						FirstFramePlayed = true
						else
						self["IsPlaying"] = false
						SafeCallEvent(self["_fireStopped"])
						if self["FadeTime"]~=nil and self.FadeTime>0 then
							self.WeightTarget = 0
							self.FadingAnimation=true
							self["IsPlaying"] = true
							self["FadeDelta"] = self["TimePosition"]
							self["TimePosition"] = self.Settings.StartsAt
							self["_tempLoop"] = true
							return
						end
						self["_tempLoop"] = nil
						ResetMotors6D(self["Motor6D"],self)
						UsedEventMarkers = {}
						connection:Disconnect()
						SafeCallEvent(self["_fireEnded"])
						coroutine.close(self["Task"])
						
					end
					
				end
				
				
				
			end
			--------
			
			---------
			if CurrentlyAtDelta > self["Length"] then
				if self["Looped"]==true then
					CurrentlyAtDelta = math.abs(self["Length"]-CurrentlyAtDelta)
					SafeCallEvent(self["_fireDidLoop"],true)
				else
					CurrentlyAtDelta = self["Length"]
				end
			end
			
			--if FirstFramePlayed == true then
			--	CurrentlyAtDelta = self["TimePosition"]
			--end
			if self.FadeDelta ~= nil then
				CurrentlyAtDelta = self.FadeDelta
			end
			
			
			
			--local Lowest,Highest = GetFrameInBetween(self.Animation,CurrentlyAtDelta)
			local CurrentPositionOfJoints = {}
			local CurrentWeightOfJoints = {}
			local PlayingAnimations = GetPlayingTracks(self)
			--warn(PlayingAnimations)
			for i,v in self.Animation do
				for _i,_v in v["Data"] do
					if CurrentPositionOfJoints[_i] ==nil then
						if CurrentlyAtDelta > v.Time then continue end
						local cframe,weight=GetFinalPositionOfJointTime(_i,CurrentlyAtDelta,self.Animation,self.Settings.Animate,self["WeightCurrent"])
						if cframe==nil then continue end
						CurrentPositionOfJoints[_i]=cframe
						CurrentWeightOfJoints[_i]=weight
					end
					
				end
			end
			
			
			
			if IsGroup == true then
				if PlayingAnimations == nil or TableLen(PlayingAnimations)==1 and self.DataID==PlayingAnimations[self.DataID] then
					for i,v in CurrentPositionOfJoints do
						TransformMotor6D(self.Motor6D,i,v)
					end
					
				else
					--Playing others
					local GiveItselfCanTransform = self.Settings.CanTransformMotor6D
					
					for i,v in PlayingAnimations do
						if self["Group"]["i"][i].Settings.CanTransformMotor6D == true then
							self["Group"]["i"][i].Settings.CanTransformMotor6D = false
						end
					end
					self.Settings.CanTransformMotor6D = true
					GiveItselfCanTransform = self.Settings.CanTransformMotor6D

					
					if GiveItselfCanTransform == true then
					
						local Priorities = {}
						for i,v in PlayingAnimations do
							Priorities[i]=self["Group"]["i"][i].Priority
						end
						
						local OnlyPlayAnimations = {}
						--local HaveFadingAnim = false
						for i,v in PriorityTable do
							local a = ReturnValuesThatFound(Priorities,v)
							if TableLen(a)>0 then
								OnlyPlayAnimations = a
								break
							end
						end
						
						--local FadingAnims = ReturnFadingAnimations(self["Group"])
						--for i,v in FadingAnims do
						--	if self["Group"]["i"][v].FadingAnimation ~= true then continue end
						--	HaveFadingAnim = true
						--	if table.find(OnlyPlayAnimations,v) == nil then
						--	table.insert(OnlyPlayAnimations,v) 
								
								
						--	end
						--end
						
						--if HaveFadingAnim == true and TableLen(OnlyPlayAnimations)==1 then
						--	OnlyPlayAnimations = {}
						--	for i,v in PlayingAnimations do
						--		table.insert(OnlyPlayAnimations,v)
						--	end
						--end
						
						
						
						--Highest Animation priority
						local CurrentPositionOfJoints = {["main"]={}}
						local CurrentWeightOfJoints = {["main"]=0}
						for i,v in OnlyPlayAnimations do
							CurrentWeightOfJoints[v] = self["Group"]["i"][v].Weight
						end
						for __i,__v in OnlyPlayAnimations do
							local Anim = self["Group"]["i"][__v]
							for i,v in Anim.Animation do
								for _i,_v in v["Data"] do
									if Anim["TimePosition"] > v.Time then continue end
									local cframe,weight=GetFinalPositionOfJointTime(_i,Anim["TimePosition"],Anim.Animation,Anim.Settings.Animate,Anim["WeightCurrent"])
									if cframe==nil then continue end
									
									if CurrentPositionOfJoints[__v] == nil then
										CurrentPositionOfJoints[__v] = {}
									end
									CurrentPositionOfJoints[__v][_i] = cframe

								end
								
								
								
									
									
									
								
								
								
								
								
								
								
								
								
							end
							--Lepr Other
							local Indexer = 0
							for i,v in CurrentPositionOfJoints do
								--if string.sub(i,1,4) == "main" then continue end
								for _i,_v in v do
									if CurrentPositionOfJoints["main"][_i]==nil then
										if _v == nil then
											_v = cframe_zero
										end
										CurrentPositionOfJoints["main"][_i] = _v
										
									else
										if CurrentWeightOfJoints[i]==nil then CurrentWeightOfJoints[i]=0 end
										
										if CurrentWeightOfJoints["main"] > CurrentWeightOfJoints[i] then
											CurrentPositionOfJoints["main"][_i] = _v:Lerp(CurrentPositionOfJoints["main"][_i],0.5)
										elseif CurrentWeightOfJoints["main"] < CurrentWeightOfJoints[i] then
											
											CurrentWeightOfJoints["main"] = CurrentWeightOfJoints[i]
											CurrentPositionOfJoints["main"][_i] = _v:Lerp(CurrentPositionOfJoints["main"][_i],0.5)
										elseif CurrentWeightOfJoints["main"] == CurrentWeightOfJoints[i] then
											
											--print(alpha)
											--if self["Group"]["i"][i]["FadingAnimation"]~= nil then 
											--	local fadingProgress = ilerp(self["Group"]["i"][i]["FadeTime"],0,self["Group"]["i"][i]["FadeMax"])
											--	alpha = fadingProgress
											--end
	
											--CurrentWeightOfJoints["main"]+=1
											-- Order???
											CurrentPositionOfJoints["main"][_i] = CurrentPositionOfJoints["main"][_i]:Lerp(_v,0.5)

										
											--something in between


										end

										--CurrentPositionOfJoints["main"][_i] = CurrentPositionOfJoints["main"][_i]:Lerp(_v,alpha)
									end


								end


							end
							--Play Result
							for i,v in CurrentPositionOfJoints["main"] do
								TransformMotor6D(Anim.Motor6D,i,v)
							end
							
						end
						
						
						
					end
				end
				
			else
				--not group
				for i,v in CurrentPositionOfJoints do
					TransformMotor6D(self.Motor6D,i,v)
				end
			end
			
			
			--TEST FIELD
			--for i,v in CurrentPositionOfJoints do
			--	self.Motor6D[i].Transform = v
				
			--end

------------------------------------------------------
			--print(CurrentlyAtDelta)
			
			if self.FadingAnimation ~= true then
				if CurrentlyAtDelta >= self["Length"] then
					CurrentlyAtDelta = self["Length"]
				self["_debugSpeed"] = nil
				MadeOneLoop = true
				if self["Looped"] == true or self["_tempLoop"]==true then
						self["TimePosition"] = self.Settings.StartsAt
						CurrentlyAtDelta = self.Settings.StartsAt
						UsedEventMarkers = {}
						FirstFramePlayed = true
						SafeCallEvent(self["_fireDidLoop"],true)
						return
				else
						self["IsPlaying"] = false
						SafeCallEvent(self["_fireStopped"])
						if self["FadeTime"]~=nil and self.FadeTime>0 then
							self.WeightTarget = 0
							self.FadingAnimation=true
							self["IsPlaying"] = true
							self["FadeDelta"] = self["TimePosition"]
							self["_tempLoop"] = true
						return
						end
						self["TimePosition"] = self.Settings.StartsAt
					self["_tempLoop"] = nil
						ResetMotors6D(self["Motor6D"],self)
					UsedEventMarkers = {}
					connection:Disconnect()
						SafeCallEvent(self["_fireEnded"])
					coroutine.close(self["Task"])
					end
					
			else
					self["TimePosition"] = CurrentlyAtDelta	
			end
			end
			FirstFramePlayed = false
			--Fading
			if self["FadingAnimation"] == true then
				if trueDelta <0 then trueDelta = 0 end
				local FadeTime = self.FadeTime-trueDelta
				if FadeTime < 0 then FadeTime = 0 end
				self["FadeTime"]=FadeTime
				local Pregress = ilerp(self["FadeTime"],0,self["FadeMax"])
				if self.WeightTarget==nil then
					self.WeightTarget = 0
				end
				if self.Weight==nil then
					self.Weight = 1
				end

				self["WeightCurrent"] = ilerp(Pregress,self["WeightTarget"],self["Weight"])
				
				--print(self.FadeTime.."/"..self.FadeMax)
				if self["FadeTime"] <= 0 then
					if self["FadedLastFrame"] ~= true then
						self["FadedLastFrame"] = true
						self["FadeTime"] = 0
						return
					end
					
					self["FadedLastFrame"] = nil
					self["FadeTime"] = nil
					self.FadeMax = nil
					self.FadeDelta = nil
					self["FadingAnimation"] = nil
					self["IsPlaying"] = false
					connection:Disconnect()
					self["_tempLoop"] = nil
					self.TimePosition = 0
					SafeCallEvent(self["_fireEnded"])
					coroutine.close(self["Task"])
						self.Settings.CanTransformMotor6D = false
					--warn("fading stopped")
				end
			end
			--------------------------------------------
		end)
	self["_Connection"] = connection

	end)
	coroutine.resume(self.Task)
	
end






return module
