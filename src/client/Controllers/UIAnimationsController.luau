local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modux = require(ReplicatedStorage.Shared.Modux)
local Spring = require(ReplicatedStorage.Packages.spring) :: any

local DEFAULT_DAMPING = 0.82
local DEFAULT_FREQUENCY = 6
local DEFAULT_EPSILON = 0.001
local OPEN_SCALE_START = 0.88
local OPEN_SCALE_END = 1
local CLOSE_SCALE_END = 0.88
local PRESS_SCALE = 0.94
local PULSE_SCALE = 1.08
local HOVER_SCALE = 1.06

local HOVER_SCALE_TAG = "UI.HoverScale"
local HOVER_FADE_TAG = "UI.HoverFade"
local PRESS_TAG = "UI.Press"
local POP_TAG = "UI.Pop"
local COLLAPSE_TAG = "UI.Collapse"
local PULSE_TAG = "UI.Pulse"

type SpringOptions = {
	TargetInstance: Instance?,
	From: any?,
	To: any?,
	Damping: number?,
	Frequency: number?,
	Epsilon: number?,
	Clock: ("RenderStepped" | "Heartbeat")?,
	Step: ((value: any, alpha: number, animation: any) -> ())?,
	Done: (() -> ())?,
	Reset: (() -> ())?,
}

type AnimationHandle<T> = {
	Completed: RBXScriptSignal,
	IsPlaying: (self: AnimationHandle<T>) -> boolean,
	Get: (self: AnimationHandle<T>) -> (T, T),
	GetCurrentPos: (self: AnimationHandle<T>) -> T,
	Set: (self: AnimationHandle<T>, value: T) -> AnimationHandle<T>,
	SetTarget: (self: AnimationHandle<T>, nextTarget: T) -> AnimationHandle<T>,
	SetConfig: (self: AnimationHandle<T>, nextDamping: number?, nextFrequency: number?) -> AnimationHandle<T>,
	Play: (self: AnimationHandle<T>, nextTarget: T?, nextFrom: T?) -> AnimationHandle<T>,
	Stop: (self: AnimationHandle<T>, finish: boolean?) -> AnimationHandle<T>,
	Reset: (self: AnimationHandle<T>) -> AnimationHandle<T>,
	Destroy: (self: AnimationHandle<T>) -> AnimationHandle<T>,
}

type GroupAnimationHandle = {
	Completed: RBXScriptSignal,
	Play: (self: GroupAnimationHandle) -> GroupAnimationHandle,
	Stop: (self: GroupAnimationHandle, finish: boolean?) -> GroupAnimationHandle,
	Reset: (self: GroupAnimationHandle) -> GroupAnimationHandle,
	GetCurrentPos: (self: GroupAnimationHandle) -> { any },
	Destroy: (self: GroupAnimationHandle) -> GroupAnimationHandle,
}

type SequenceAnimationHandle = {
	Completed: RBXScriptSignal,
	Play: (self: SequenceAnimationHandle) -> SequenceAnimationHandle,
	Next: (self: SequenceAnimationHandle) -> SequenceAnimationHandle,
	Stop: (self: SequenceAnimationHandle, finish: boolean?) -> SequenceAnimationHandle,
	Reset: (self: SequenceAnimationHandle) -> SequenceAnimationHandle,
	GetCurrentPos: (self: SequenceAnimationHandle) -> any,
	Destroy: (self: SequenceAnimationHandle) -> SequenceAnimationHandle,
}

local UIAnimationsController = Modux.Controller("UIAnimationsController")
type Self = typeof(UIAnimationsController)

UIAnimationsController.ActiveConnections = {} :: { [GuiObject]: RBXScriptConnection }
UIAnimationsController.ActiveAnimations = {} :: { [Instance]: { [any]: boolean } }
UIAnimationsController.TaggedTasks = {} :: { [Instance]: { [string]: { any } } }

local function zeroVelocity(value: any): any
	if typeof(value) == "Vector3" then
		return Vector3.zero
	end

	return 0
end

local function magnitude(value: any): number
	if typeof(value) == "number" then
		return math.abs(value)
	end

	if typeof(value) == "Vector3" then
		return value.Magnitude
	end

	return 0
end

local function alphaFrom(fromValue: any, toValue: any, value: any, epsilon: number): number
	if typeof(fromValue) ~= "number" or typeof(toValue) ~= "number" or typeof(value) ~= "number" then
		return 1
	end

	local span = toValue - fromValue
	if math.abs(span) <= epsilon then
		return 1
	end

	return math.clamp((value - fromValue) / span, 0, 1)
end

local function disconnect(connection: RBXScriptConnection?)
	if connection then
		connection:Disconnect()
	end
end

local function cleanupTask(task: any)
	if typeof(task) == "RBXScriptConnection" then
		task:Disconnect()
	elseif typeof(task) == "function" then
		task()
	elseif typeof(task) == "table" then
		if typeof(task.Destroy) == "function" then
			task:Destroy()
		elseif typeof(task.Disconnect) == "function" then
			task:Disconnect()
		end
	end
end

local function getNumberAttribute(instance: Instance, attributeName: string, fallback: number): number
	local value = instance:GetAttribute(attributeName)
	if typeof(value) == "number" then
		return value
	end

	return fallback
end

local function getClockAttribute(instance: Instance): "RenderStepped" | "Heartbeat" | nil
	local value = instance:GetAttribute("Clock")
	if value == "RenderStepped" or value == "Heartbeat" then
		return value
	end

	return nil
end

local function getTaggedSpringOptions(instance: Instance): SpringOptions
	return {
		Damping = getNumberAttribute(instance, "Damping", DEFAULT_DAMPING),
		Frequency = getNumberAttribute(instance, "Frequency", DEFAULT_FREQUENCY),
		Epsilon = getNumberAttribute(instance, "Epsilon", DEFAULT_EPSILON),
		Clock = getClockAttribute(instance),
	}
end

local function getTaggedGuiObject(instance: Instance, tag: string): GuiObject?
	if not instance:IsA("GuiObject") then
		warn(`[UIAnimationsController] "{instance:GetFullName()}" usa {tag}, mas nao e GuiObject.`)
		return nil
	end

	return instance :: GuiObject
end

local function setTransparency(target: GuiObject, value: number)
	if target:IsA("CanvasGroup") then
		(target :: CanvasGroup).GroupTransparency = value
		return
	end

	if target:IsA("TextLabel") or target:IsA("TextButton") or target:IsA("TextBox") then
		(target :: TextLabel).TextTransparency = value
	end

	if target:IsA("ImageLabel") or target:IsA("ImageButton") then
		(target :: ImageLabel).ImageTransparency = value
	end

	target.BackgroundTransparency = value
end

local function getTransparency(target: GuiObject): number
	if target:IsA("CanvasGroup") then
		return (target :: CanvasGroup).GroupTransparency
	end

	if target:IsA("TextLabel") or target:IsA("TextButton") or target:IsA("TextBox") then
		return (target :: TextLabel).TextTransparency
	end

	if target:IsA("ImageLabel") or target:IsA("ImageButton") then
		return (target :: ImageLabel).ImageTransparency
	end

	return target.BackgroundTransparency
end

UIAnimationsController.EnsureScale = function(self: Self, window: GuiObject): UIScale
	local scale = window:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = window
	end

	return scale :: UIScale
end

UIAnimationsController.FindCanvas = function(self: Self, window: GuiObject): CanvasGroup?
	if window:IsA("CanvasGroup") then
		return window :: CanvasGroup
	end

	return window:FindFirstChildOfClass("CanvasGroup")
end

UIAnimationsController.RegisterAnimation = function(self: Self, target: Instance?, animation)
	if not target then
		return
	end

	if not self.ActiveAnimations[target] then
		self.ActiveAnimations[target] = {}
	end

	self.ActiveAnimations[target][animation] = true
end

UIAnimationsController.UnregisterAnimation = function(self: Self, target: Instance?, animation)
	if not target then
		return
	end

	local animations = self.ActiveAnimations[target]
	if not animations then
		return
	end

	animations[animation] = nil
	if next(animations) == nil then
		self.ActiveAnimations[target] = nil
	end
end

UIAnimationsController.Stop = function(self: Self, target: Instance)
	local animations = self.ActiveAnimations[target]
	if animations then
		local list = {}
		for animation in animations do
			table.insert(list, animation)
		end

		for _, animation in list do
			animation:Stop()
		end
	end

	local legacyConnection = self.ActiveConnections[target]
	if legacyConnection then
		legacyConnection:Disconnect()
		self.ActiveConnections[target] = nil
	end
end

UIAnimationsController.IsTaggedBound = function(self: Self, instance: Instance, tag: string): boolean
	local tagTasks = self.TaggedTasks[instance]
	return tagTasks ~= nil and tagTasks[tag] ~= nil
end

UIAnimationsController.TrackTaggedTasks = function(self: Self, instance: Instance, tag: string, tasks: { any })
	if not self.TaggedTasks[instance] then
		self.TaggedTasks[instance] = {}
	end

	self.TaggedTasks[instance][tag] = tasks
end

UIAnimationsController.UnbindTag = function(self: Self, instance: Instance, tag: string)
	local tagTasks = self.TaggedTasks[instance]
	if not tagTasks then
		return
	end

	local tasks = tagTasks[tag]
	if not tasks then
		return
	end

	tagTasks[tag] = nil
	for _, task in tasks do
		cleanupTask(task)
	end

	if next(tagTasks) == nil then
		self.TaggedTasks[instance] = nil
	end
end

UIAnimationsController.UnbindAllTags = function(self: Self, instance: Instance)
	local tagTasks = self.TaggedTasks[instance]
	if not tagTasks then
		return
	end

	local tags = {}
	for tag in tagTasks do
		table.insert(tags, tag)
	end

	for _, tag in tags do
		self:UnbindTag(instance, tag)
	end
end

UIAnimationsController.BindTaggedPreset = function(
	self: Self,
	tag: string,
	binder: (self: any, instance: Instance) -> ()
)
	for _, instance in CollectionService:GetTagged(tag) do
		binder(self, instance)
	end

	local addedConnection = CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		binder(self, instance)
	end)
	self:Cleanup(addedConnection)

	local removedConnection = CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		self:UnbindTag(instance, tag)
	end)
	self:Cleanup(removedConnection)
end

UIAnimationsController.CreateSpring = function(self: Self, options: SpringOptions): AnimationHandle<any>
	local controller = self
	local targetInstance = options.TargetInstance
	local fromValue = if options.From ~= nil then options.From else 0
	local toValue = if options.To ~= nil then options.To else fromValue
	local damping = options.Damping or DEFAULT_DAMPING
	local frequency = options.Frequency or DEFAULT_FREQUENCY
	local epsilon = options.Epsilon or DEFAULT_EPSILON
	local clock = options.Clock or "RenderStepped"
	local step = options.Step
	local done = options.Done
	local reset = options.Reset

	local spring = Spring.new(fromValue)
	spring.Damping = damping
	spring.Frequency = frequency
	spring:SetTarget(toValue)

	local completedEvent = Instance.new("BindableEvent")
	local handle = {
		Completed = completedEvent.Event,
	}
	local connection: RBXScriptConnection? = nil
	local playing = false
	local destroyed = false

	local function apply(value: any, alpha: number)
		if step then
			step(value, alpha, handle)
		end
	end

	local function stopConnection()
		disconnect(connection)
		connection = nil
		playing = false
		controller:UnregisterAnimation(targetInstance, handle)
	end

	function handle:IsPlaying(): boolean
		return playing
	end

	function handle:Get(): (any, any)
		return spring.Position, spring.Velocity
	end

	function handle:GetCurrentPos(): any
		return spring.Position
	end

	function handle:Set(value: any)
		fromValue = value
		spring.Position = value
		spring.Velocity = zeroVelocity(value)
		apply(value, alphaFrom(fromValue, toValue, value, epsilon))
		return self
	end

	function handle:SetTarget(nextTarget: any)
		toValue = nextTarget
		spring:SetTarget(nextTarget)
		return self
	end

	function handle:SetConfig(nextDamping: number?, nextFrequency: number?)
		if nextDamping then
			damping = nextDamping
			spring.Damping = nextDamping
		end

		if nextFrequency then
			frequency = nextFrequency
			spring.Frequency = nextFrequency
		end

		return self
	end

	function handle:Play(nextTarget: any?, nextFrom: any?)
		if destroyed then
			return self
		end

		stopConnection()

		if nextFrom ~= nil then
			fromValue = nextFrom
			spring.Position = nextFrom
			spring.Velocity = zeroVelocity(nextFrom)
			apply(nextFrom, 0)
		else
			fromValue = spring.Position
		end

		if nextTarget ~= nil then
			toValue = nextTarget
		end

		spring.Damping = damping
		spring.Frequency = frequency
		spring:SetTarget(toValue)
		playing = true
		controller:RegisterAnimation(targetInstance, handle)

		local signal = if clock == "Heartbeat" then RunService.Heartbeat else RunService.RenderStepped
		connection = signal:Connect(function(deltaTime)
			spring:Update(deltaTime)

			local value = spring.Position
			local alpha = alphaFrom(fromValue, toValue, value, epsilon)
			apply(value, alpha)

			local distance = magnitude(value - toValue)
			local velocity = magnitude(spring.Velocity)
			if distance <= epsilon and velocity <= epsilon then
				stopConnection()
				spring.Position = toValue
				spring.Velocity = zeroVelocity(toValue)
				apply(toValue, 1)

				if done then
					done()
				end

				completedEvent:Fire(Enum.PlaybackState.Completed)
			end
		end)

		controller:Cleanup(connection :: RBXScriptConnection)
		return self
	end

	function handle:Stop(finish: boolean?)
		local wasPlaying = playing
		stopConnection()
		if finish then
			spring.Position = toValue
			spring.Velocity = zeroVelocity(toValue)
			apply(toValue, 1)
		end

		if wasPlaying then
			completedEvent:Fire(if finish then Enum.PlaybackState.Completed else Enum.PlaybackState.Cancelled)
		end

		return self
	end

	function handle:Reset()
		stopConnection()
		spring.Position = fromValue
		spring.Velocity = zeroVelocity(fromValue)
		spring:SetTarget(fromValue)
		apply(fromValue, 0)

		if reset then
			reset()
		end

		return self
	end

	function handle:Destroy()
		destroyed = true
		stopConnection()
		completedEvent:Destroy()
		return self
	end

	return handle
end

UIAnimationsController.Group = function(self: Self, animations: { any }): GroupAnimationHandle
	local completedEvent = Instance.new("BindableEvent")
	local completedConnections = {}
	local handle = {
		Completed = completedEvent.Event,
	}

	local function disconnectCompleted()
		for _, connection in completedConnections do
			disconnect(connection)
		end

		table.clear(completedConnections)
	end

	function handle:Play()
		disconnectCompleted()
		local completedCount = 0

		for _, animation in animations do
			if animation.Completed then
				local completedConnection = animation.Completed:Connect(function()
					completedCount += 1
					if completedCount >= #animations then
						disconnectCompleted()
						completedEvent:Fire(Enum.PlaybackState.Completed)
					end
				end)
				table.insert(completedConnections, completedConnection)
			end
		end

		for _, animation in animations do
			animation:Play()
		end
		return self
	end

	function handle:Stop(finish: boolean?)
		disconnectCompleted()
		for _, animation in animations do
			animation:Stop(finish)
		end

		completedEvent:Fire(if finish then Enum.PlaybackState.Completed else Enum.PlaybackState.Cancelled)
		return self
	end

	function handle:Reset()
		for _, animation in animations do
			animation:Reset()
		end
		return self
	end

	function handle:GetCurrentPos(): { any }
		local positions = {}
		for _, animation in animations do
			table.insert(positions, if animation.GetCurrentPos then animation:GetCurrentPos() else animation:Get())
		end

		return positions
	end

	function handle:Destroy()
		disconnectCompleted()
		for _, animation in animations do
			if animation.Destroy then
				animation:Destroy()
			else
				animation:Stop()
			end
		end
		completedEvent:Destroy()
		return self
	end

	return handle
end

UIAnimationsController.Sequence = function(self: Self, animations: { any }): SequenceAnimationHandle
	local completedEvent = Instance.new("BindableEvent")
	local handle = {
		Completed = completedEvent.Event,
	}
	local currentIndex = 1
	local playing = false

	function handle:Play()
		currentIndex = 1
		playing = true
		local animation = animations[currentIndex]
		if animation then
			animation:Play()
		else
			playing = false
			completedEvent:Fire(Enum.PlaybackState.Completed)
		end

		return self
	end

	function handle:Next()
		currentIndex += 1
		local animation = animations[currentIndex]
		if animation then
			animation:Play()
		else
			playing = false
			completedEvent:Fire(Enum.PlaybackState.Completed)
		end

		return self
	end

	function handle:Stop(finish: boolean?)
		local wasPlaying = playing
		playing = false
		for _, animation in animations do
			animation:Stop(finish)
		end

		if wasPlaying then
			completedEvent:Fire(if finish then Enum.PlaybackState.Completed else Enum.PlaybackState.Cancelled)
		end

		return self
	end

	function handle:Reset()
		currentIndex = 1
		playing = false
		for _, animation in animations do
			animation:Reset()
		end

		return self
	end

	function handle:GetCurrentPos(): any
		local animation = animations[currentIndex]
		if not animation then
			return nil
		end

		return if animation.GetCurrentPos then animation:GetCurrentPos() else animation:Get()
	end

	function handle:Destroy()
		playing = false
		for _, animation in animations do
			if animation.Destroy then
				animation:Destroy()
			else
				animation:Stop()
			end
		end

		completedEvent:Destroy()
		return self
	end

	return handle
end

UIAnimationsController.Scale = function(
	self: Self,
	window: GuiObject,
	toScale: number,
	options: SpringOptions?
): AnimationHandle<number>
	options = options or {}
	if not options then
		return {} :: AnimationHandle<number>
	end
	local scale = self:EnsureScale(window)
	local fromScale = if options.From ~= nil then options.From else scale.Scale
	local userStep = options.Step

	return self:CreateSpring({
		TargetInstance = options.TargetInstance or window,
		From = fromScale,
		To = toScale,
		Damping = options.Damping,
		Frequency = options.Frequency,
		Epsilon = options.Epsilon,
		Clock = options.Clock,
		Done = options.Done,
		Reset = options.Reset,
		Step = function(value, alpha, animation)
			scale.Scale = value
			if userStep then
				userStep(value, alpha, animation)
			end
		end,
	})
end

UIAnimationsController.Fade = function(
	self: Self,
	target: GuiObject,
	toTransparency: number,
	options: SpringOptions?
): AnimationHandle<number>
	options = options or {}
	if not options then
		return {} :: AnimationHandle<number>
	end
	local fadeTarget = self:FindCanvas(target) or target
	local fromTransparency = if options.From ~= nil then options.From else getTransparency(fadeTarget)
	local userStep = options.Step

	return self:CreateSpring({
		TargetInstance = options.TargetInstance or target,
		From = fromTransparency,
		To = toTransparency,
		Damping = options.Damping,
		Frequency = options.Frequency,
		Epsilon = options.Epsilon,
		Clock = options.Clock,
		Done = options.Done,
		Reset = options.Reset,
		Step = function(value, alpha, animation)
			setTransparency(fadeTarget, value)
			if userStep then
				userStep(value, alpha, animation)
			end
		end,
	})
end

UIAnimationsController.Slide = function(
	self: Self,
	window: GuiObject,
	toPosition: UDim2,
	options: SpringOptions?
): AnimationHandle<number>
	options = options or {}
	if not options then
		return {} :: AnimationHandle<number>
	end
	local fromPosition = options.From or window.Position
	local userStep = options.Step

	return self:CreateSpring({
		TargetInstance = options.TargetInstance or window,
		From = 0,
		To = 1,
		Damping = options.Damping,
		Frequency = options.Frequency,
		Epsilon = options.Epsilon,
		Clock = options.Clock,
		Done = options.Done,
		Reset = function()
			window.Position = fromPosition
			if options.Reset then
				options.Reset()
			end
		end,
		Step = function(value, alpha, animation)
			window.Position = fromPosition:Lerp(toPosition, value)
			if userStep then
				userStep(value, alpha, animation)
			end
		end,
	})
end

UIAnimationsController.Bar = function(
	self: Self,
	fill: GuiObject,
	ratio: number,
	options: SpringOptions?
): AnimationHandle<number>
	options = options or {}
	if not options then
		return {} :: AnimationHandle<number>
	end
	local currentSize = fill.Size
	local fromRatio = if options.From ~= nil then options.From else currentSize.X.Scale
	local toRatio = math.clamp(ratio, 0, 1)
	local userStep = options.Step

	return self:CreateSpring({
		TargetInstance = options.TargetInstance or fill,
		From = fromRatio,
		To = toRatio,
		Damping = options.Damping,
		Frequency = options.Frequency,
		Epsilon = options.Epsilon,
		Clock = options.Clock,
		Done = options.Done,
		Reset = options.Reset,
		Step = function(value, alpha, animation)
			fill.Size =
				UDim2.new(math.clamp(value, 0, 1), currentSize.X.Offset, currentSize.Y.Scale, currentSize.Y.Offset)
			if userStep then
				userStep(value, alpha, animation)
			end
		end,
	})
end

UIAnimationsController.Pop = function(self: Self, window: GuiObject, options: SpringOptions?): AnimationHandle<number>
	options = options or {}
	if not options then
		return {} :: AnimationHandle<number>
	end
	window.Visible = true

	local canvas = self:FindCanvas(window)
	if canvas then
		canvas.GroupTransparency = 1
	end

	return self:Scale(window, OPEN_SCALE_END, {
		From = options.From or OPEN_SCALE_START,
		Damping = options.Damping,
		Frequency = options.Frequency,
		Epsilon = options.Epsilon,
		Clock = options.Clock,
		Done = options.Done,
		Step = function(value, alpha, animation)
			if canvas then
				canvas.GroupTransparency = 1 - alpha
			end

			if options.Step then
				options.Step(value, alpha, animation)
			end
		end,
	})
end

UIAnimationsController.Collapse = function(
	self: Self,
	window: GuiObject,
	options: SpringOptions?
): AnimationHandle<number>
	options = options or {}
	if not options then
		return {} :: AnimationHandle<number>
	end
	local canvas = self:FindCanvas(window)
	local scale = self:EnsureScale(window)

	return self:Scale(window, options.To or CLOSE_SCALE_END, {
		From = options.From or scale.Scale,
		Damping = options.Damping,
		Frequency = options.Frequency,
		Epsilon = options.Epsilon,
		Clock = options.Clock,
		Step = function(value, alpha, animation)
			if canvas then
				canvas.GroupTransparency = alpha
			end

			if options.Step then
				options.Step(value, alpha, animation)
			end
		end,
		Done = function()
			window.Visible = false
			scale.Scale = 1

			if canvas then
				canvas.GroupTransparency = 0
			end

			if options.Done then
				options.Done()
			end
		end,
	})
end

UIAnimationsController.Press = function(self: Self, window: GuiObject, options: SpringOptions?): SequenceAnimationHandle
	options = options or {}
	if not options then
		return {} :: SequenceAnimationHandle
	end
	local baseScale = if options.From ~= nil then options.From else self:EnsureScale(window).Scale
	local downScale = options.To or PRESS_SCALE
	local upAnimation
	local downAnimation
	local sequence

	upAnimation = self:Scale(window, baseScale, {
		Damping = options.Damping,
		Frequency = options.Frequency,
		Epsilon = options.Epsilon,
		Clock = options.Clock,
		Done = function()
			if options.Done then
				options.Done()
			end

			sequence:Next()
		end,
	})

	downAnimation = self:Scale(window, downScale, {
		From = baseScale,
		Damping = options.Damping,
		Frequency = options.Frequency,
		Epsilon = options.Epsilon,
		Clock = options.Clock,
		Done = function()
			sequence:Next()
		end,
	})

	sequence = self:Sequence({ downAnimation, upAnimation })

	return sequence
end

UIAnimationsController.Pulse = function(self: Self, window: GuiObject, options: SpringOptions?): SequenceAnimationHandle
	options = options or {}
	if not options then
		return {} :: SequenceAnimationHandle
	end
	local baseScale = if options.From ~= nil then options.From else self:EnsureScale(window).Scale
	local peakScale = options.To or PULSE_SCALE
	local returnAnimation
	local peakAnimation
	local sequence

	returnAnimation = self:Scale(window, baseScale, {
		Damping = options.Damping,
		Frequency = options.Frequency,
		Epsilon = options.Epsilon,
		Clock = options.Clock,
		Done = function()
			if options.Done then
				options.Done()
			end

			sequence:Next()
		end,
	})

	peakAnimation = self:Scale(window, peakScale, {
		From = baseScale,
		Damping = options.Damping,
		Frequency = options.Frequency,
		Epsilon = options.Epsilon,
		Clock = options.Clock,
		Done = function()
			sequence:Next()
		end,
	})

	sequence = self:Sequence({ peakAnimation, returnAnimation })

	return sequence
end

UIAnimationsController.PlayScale = function(
	self: Self,
	window: GuiObject,
	fromScale: number,
	toScale: number,
	onStep: ((alpha: number) -> ())?,
	onDone: (() -> ())?
): AnimationHandle<number>
	self:Stop(window)
	local animation = self:Scale(window, toScale, {
		From = fromScale,
		Step = function(_value, alpha)
			if onStep then
				onStep(alpha)
			end
		end,
		Done = onDone,
	})

	animation:Play()
	return animation
end

UIAnimationsController.Open = function(self: Self, window: GuiObject): AnimationHandle<number>
	self:Stop(window)
	local animation = self:Pop(window)
	animation:Play()
	return animation
end

UIAnimationsController.Close = function(self: Self, window: GuiObject, onDone: (() -> ())?): AnimationHandle<number>
	self:Stop(window)
	local animation = self:Collapse(window, {
		Done = onDone,
	})
	animation:Play()
	return animation
end

UIAnimationsController.BindHoverScale = function(self: Self, instance: Instance)
	if self:IsTaggedBound(instance, HOVER_SCALE_TAG) then
		return
	end

	local window = getTaggedGuiObject(instance, HOVER_SCALE_TAG)
	if not window then
		return
	end

	local scale = self:EnsureScale(window)
	local baseScale = getNumberAttribute(window, "BaseScale", scale.Scale)
	local hoverScale = getNumberAttribute(window, "HoverScale", baseScale * HOVER_SCALE)
	local animation = self:Scale(window, baseScale, getTaggedSpringOptions(window))

	local enterConnection = window.MouseEnter:Connect(function()
		animation:Play(hoverScale)
	end)

	local leaveConnection = window.MouseLeave:Connect(function()
		animation:Play(baseScale)
	end)

	local destroyingConnection = window.Destroying:Connect(function()
		self:UnbindTag(window, HOVER_SCALE_TAG)
	end)

	self:TrackTaggedTasks(window, HOVER_SCALE_TAG, {
		enterConnection,
		leaveConnection,
		destroyingConnection,
		function()
			animation:Destroy()
		end,
	})
end

UIAnimationsController.BindHoverFade = function(self: Self, instance: Instance)
	if self:IsTaggedBound(instance, HOVER_FADE_TAG) then
		return
	end

	local window = getTaggedGuiObject(instance, HOVER_FADE_TAG)
	if not window then
		return
	end

	local fadeTarget = self:FindCanvas(window) or window
	local idleTransparency = getNumberAttribute(window, "IdleTransparency", getTransparency(fadeTarget))
	local hoverTransparency = getNumberAttribute(window, "HoverTransparency", 0)
	local animation = self:Fade(window, idleTransparency, getTaggedSpringOptions(window))

	local enterConnection = window.MouseEnter:Connect(function()
		animation:Play(hoverTransparency)
	end)

	local leaveConnection = window.MouseLeave:Connect(function()
		animation:Play(idleTransparency)
	end)

	local destroyingConnection = window.Destroying:Connect(function()
		self:UnbindTag(window, HOVER_FADE_TAG)
	end)

	self:TrackTaggedTasks(window, HOVER_FADE_TAG, {
		enterConnection,
		leaveConnection,
		destroyingConnection,
		function()
			animation:Destroy()
		end,
	})
end

UIAnimationsController.BindPress = function(self: Self, instance: Instance)
	if self:IsTaggedBound(instance, PRESS_TAG) then
		return
	end

	if not instance:IsA("GuiButton") then
		warn(`[UIAnimationsController] "{instance:GetFullName()}" usa {PRESS_TAG}, mas nao e GuiButton.`)
		return
	end

	local button = instance :: GuiButton
	local scale = self:EnsureScale(button)
	local baseScale = getNumberAttribute(button, "BaseScale", scale.Scale)
	local hoverScale = getNumberAttribute(button, "HoverScale", baseScale * 1.03)
	local pressScale = getNumberAttribute(button, "PressScale", PRESS_SCALE)
	local animation = self:Scale(button, baseScale, getTaggedSpringOptions(button))
	local isHovering = false
	local isPressed = false

	local function playCurrentTarget()
		if isPressed then
			animation:Play(pressScale)
		elseif isHovering then
			animation:Play(hoverScale)
		else
			animation:Play(baseScale)
		end
	end

	local enterConnection = button.MouseEnter:Connect(function()
		isHovering = true
		playCurrentTarget()
	end)

	local leaveConnection = button.MouseLeave:Connect(function()
		isHovering = false
		isPressed = false
		playCurrentTarget()
	end)

	local downConnection = button.MouseButton1Down:Connect(function()
		isPressed = true
		playCurrentTarget()
	end)

	local upConnection = button.MouseButton1Up:Connect(function()
		isPressed = false
		playCurrentTarget()
	end)

	local destroyingConnection = button.Destroying:Connect(function()
		self:UnbindTag(button, PRESS_TAG)
	end)

	self:TrackTaggedTasks(button, PRESS_TAG, {
		enterConnection,
		leaveConnection,
		downConnection,
		upConnection,
		destroyingConnection,
		function()
			animation:Destroy()
		end,
	})
end

UIAnimationsController.PlayTaggedPop = function(self: Self, instance: Instance)
	if self:IsTaggedBound(instance, POP_TAG) then
		return
	end

	local window = getTaggedGuiObject(instance, POP_TAG)
	if not window then
		return
	end

	local animation = self:Pop(window, {
		Damping = getNumberAttribute(window, "Damping", DEFAULT_DAMPING),
		Frequency = getNumberAttribute(window, "Frequency", DEFAULT_FREQUENCY),
		Epsilon = getNumberAttribute(window, "Epsilon", DEFAULT_EPSILON),
		Clock = getClockAttribute(window),
	})
	animation:Play()

	local destroyingConnection = window.Destroying:Connect(function()
		self:UnbindTag(window, POP_TAG)
	end)

	self:TrackTaggedTasks(window, POP_TAG, {
		destroyingConnection,
		function()
			animation:Destroy()
		end,
	})
end

UIAnimationsController.PlayTaggedCollapse = function(self: Self, instance: Instance)
	if self:IsTaggedBound(instance, COLLAPSE_TAG) then
		return
	end

	local window = getTaggedGuiObject(instance, COLLAPSE_TAG)
	if not window then
		return
	end

	local animation = self:Collapse(window, {
		Damping = getNumberAttribute(window, "Damping", DEFAULT_DAMPING),
		Frequency = getNumberAttribute(window, "Frequency", DEFAULT_FREQUENCY),
		Epsilon = getNumberAttribute(window, "Epsilon", DEFAULT_EPSILON),
		Clock = getClockAttribute(window),
	})
	animation:Play()

	local destroyingConnection = window.Destroying:Connect(function()
		self:UnbindTag(window, COLLAPSE_TAG)
	end)

	self:TrackTaggedTasks(window, COLLAPSE_TAG, {
		destroyingConnection,
		function()
			animation:Destroy()
		end,
	})
end

UIAnimationsController.PlayTaggedPulse = function(self: Self, instance: Instance)
	if self:IsTaggedBound(instance, PULSE_TAG) then
		return
	end

	local window = getTaggedGuiObject(instance, PULSE_TAG)
	if not window then
		return
	end

	local animation = self:Pulse(window, {
		To = getNumberAttribute(window, "PulseScale", PULSE_SCALE),
		Damping = getNumberAttribute(window, "Damping", DEFAULT_DAMPING),
		Frequency = getNumberAttribute(window, "Frequency", DEFAULT_FREQUENCY),
		Epsilon = getNumberAttribute(window, "Epsilon", DEFAULT_EPSILON),
		Clock = getClockAttribute(window),
	})
	animation:Play()

	local destroyingConnection = window.Destroying:Connect(function()
		self:UnbindTag(window, PULSE_TAG)
	end)

	self:TrackTaggedTasks(window, PULSE_TAG, {
		destroyingConnection,
		function()
			animation:Destroy()
		end,
	})
end

UIAnimationsController:OnInit(function(self)
	local tags = {
		[HOVER_SCALE_TAG] = self.BindHoverScale,
		[HOVER_FADE_TAG] = self.BindHoverFade,
		[PRESS_TAG] = self.BindPress,
		[POP_TAG] = self.PlayTaggedPop,
		[COLLAPSE_TAG] = self.PlayTaggedCollapse,
		[PULSE_TAG] = self.PlayTaggedPulse,
	}

	for tag, binder in tags do
		self:BindTaggedPreset(tag, binder)
	end
end)

UIAnimationsController:OnDestroy(function(self)
	local taggedInstances = {}
	for instance in self.TaggedTasks do
		table.insert(taggedInstances, instance)
	end

	for _, instance in taggedInstances do
		self:UnbindAllTags(instance)
	end

	for target, animations in self.ActiveAnimations do
		for animation in animations do
			animation:Destroy()
		end

		self.ActiveAnimations[target] = nil
	end

	for window, connection in self.ActiveConnections do
		connection:Disconnect()
		self.ActiveConnections[window] = nil
	end
end)

return UIAnimationsController
