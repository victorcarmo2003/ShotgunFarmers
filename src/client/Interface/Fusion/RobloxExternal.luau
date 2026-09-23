--!strict
--!nolint LocalUnused
--!nolint LocalShadow

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Package = script.Parent
local External = require(Package.External)

local RobloxExternal = {}

RobloxExternal.policies = {
	allowWebLinks = RunService:IsStudio(),
}

function RobloxExternal.doTaskImmediate(resume: () -> ())
	task.spawn(resume)
end

function RobloxExternal.doTaskDeferred(resume: () -> ())
	task.defer(resume)
end

function RobloxExternal.logErrorNonFatal(errorString: string)
	task.spawn(error, errorString, 0)
end

RobloxExternal.logWarn = warn

local function performUpdateStep()
	External.performUpdateStep(os.clock())
end

local stopSchedulerFunc = nil :: (() -> ())?
function RobloxExternal.startScheduler()
	if stopSchedulerFunc ~= nil then
		return
	end
	if RunService:IsClient() then
		local id = "FusionUpdateStep_" .. HttpService:GenerateGUID()
		RunService:BindToRenderStep(id, Enum.RenderPriority.First.Value, performUpdateStep)
		stopSchedulerFunc = function()
			RunService:UnbindFromRenderStep(id)
		end
	else
		local connection = RunService.Heartbeat:Connect(performUpdateStep)
		stopSchedulerFunc = function()
			connection:Disconnect()
		end
	end
end

function RobloxExternal.stopScheduler()
	if stopSchedulerFunc ~= nil then
		stopSchedulerFunc()
		stopSchedulerFunc = nil
	end
end

return RobloxExternal
