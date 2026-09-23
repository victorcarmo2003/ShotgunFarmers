--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Settings = require(ReplicatedStorage.shared.DayNight.DayCycleSettings)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

export type Cycle = "Day" | "Night" | "Idle" | "Transition"

const TRANSITION = {
	Damping = 1,
	Frequency = 0.2,
	Epsilon = 0.01,
}

const DayNightService = Modux.Service("DayNightService", { Priority = 690 })

function DayNightService:Setup()
	self.Cycle = "Idle" :: Cycle
	self.Day = 0 :: number
	self.SecondsLeft = 0 :: number
	self.Running = false :: boolean
	self.CycleChanged = self.Libs.Signal.new() :: SignalLib.Signal<Cycle, Cycle>
end

local function nightClockTarget(currentClock: number): number
	if Settings.NightClock <= currentClock then
		return Settings.NightClock + 24
	end

	return Settings.NightClock
end

function DayNightService:SetCycle(cycle: Cycle)
	const previous = self.Cycle
	if previous == cycle then
		return
	end

	self.Cycle = cycle
	self.CycleChanged:Fire(previous, cycle)

	if previous == "Night" then
		self.Day += 1
	end
end

function DayNightService:Transition(target: "Day" | "Night")
	self:SetCycle("Transition")

	const goals = if target == "Night"
		then { ClockTime = nightClockTarget(Lighting.ClockTime), Brightness = Settings.NightBrightness }
		else { ClockTime = Settings.DayClock, Brightness = Settings.DayBrightness }

	const animation = self.Libs.Spring:Create(Lighting, goals, {
		Damping = TRANSITION.Damping,
		Frequency = TRANSITION.Frequency,
		Epsilon = TRANSITION.Epsilon,
	})

	animation:Play()
	animation.Completed:Wait()

	if target == "Night" then
		Lighting.ClockTime = Settings.NightClock
		self.SecondsLeft = Settings.NightDuration
		self:SetCycle("Night")
	else
		self.SecondsLeft = Settings.DayDuration
		self:SetCycle("Day")
	end
end

function DayNightService:Toggle()
	if self.Cycle == "Day" then
		self:Transition("Night")
	elseif self.Cycle == "Night" then
		self:Transition("Day")
	end
end

function DayNightService:StartCycle()
	self.SecondsLeft = Settings.DayDuration
	self.Running = true
	self:SetCycle("Day")
end

function DayNightService:GetCycle(): Cycle
	return self.Cycle
end

function DayNightService:GetDay(): number
	return self.Day
end

DayNightService:OnInit(function(self)
	self:Setup()
end)

DayNightService:OnTick(function(self)
	if not self.Running or self.Cycle == "Transition" then
		return
	end

	if self.SecondsLeft > 0 then
		self.SecondsLeft -= 1
		return
	end

	task.spawn(function()
		self:Toggle()
	end)
end, 1)

return DayNightService
