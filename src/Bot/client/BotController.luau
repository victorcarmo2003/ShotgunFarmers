--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local BotNet = require(ReplicatedStorage.shared.Bot.Net)
local BotSettings = require(ReplicatedStorage.shared.Bot.BotSettings)
local GetAnimations = require(ReplicatedStorage.shared.Character.GetAnimations)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

type Member = BotNet.Member

export type Sample = {
	Time: number,
	Position: Vector3,
	LookAt: Vector3,
	State: BotNet.BotState,
	MoveDir: Vector2,
	WeaponID: number,
}

export type View = {
	GameID: number,
	Buffer: { Sample },
	Model: Model?,
	Root: BasePart?,
	Animator: Animator?,
	Tracks: { [string]: AnimationTrack },
	Playing: string?,
	Hold: AnimationTrack?,
	WeaponID: number,
	Weapon: Model?,
	Dead: boolean,
	Fresh: boolean,
	Rebuild: boolean,
}

const MAX_SAMPLES = 30
const FADE_TIME = 0.15
const RUN_THRESHOLD = 0.1
const MIN_RUN_SPEED = 0.6
const MAX_RUN_SPEED = 1.3
const MAX_EXTRAPOLATION = 0.15
const THUMBNAIL_TYPE = Enum.ThumbnailType.HeadShot
const THUMBNAIL_SIZE = Enum.ThumbnailSize.Size150x150

const BotController = Modux.Controller("BotController", { Priority = 480 })

function BotController:Setup()
	self.Members = {} :: { [number]: Member }
	self.ByUserId = {} :: { [number]: number }
	self.Views = {} :: { [number]: View }
	self.Thumbnails = {} :: { [number]: string }
	self.Changed = self.Libs.Signal.new() :: SignalLib.Signal<number>
	self.ModelAdded = self.Libs.Signal.new() :: SignalLib.Signal<number, Model>

	const folder = Instance.new("Folder")
	folder.Name = BotSettings.ModelFolder
	folder.Parent = workspace
	self.Folder = folder :: Folder
end

function BotController:Find(gameId: number): Member?
	return self.Members[gameId]
end

function BotController:FindByUserId(userId: number): (number?, Member?)
	const gameId = self.ByUserId[userId]
	if not gameId then
		return nil, nil
	end
	return gameId, self.Members[gameId]
end

function BotController:ModelOf(gameId: number): Model?
	const view = self.Views[gameId]
	if not view or view.Dead then
		return nil
	end
	return view.Model
end

function BotController:Thumbnail(member: Member): string
	const avatarId = member.AvatarId
	if avatarId <= 0 then
		return ""
	end

	const cached = self.Thumbnails[avatarId]
	if cached then
		return cached
	end

	const ok, content = pcall(function()
		return Players:GetUserThumbnailAsync(avatarId, THUMBNAIL_TYPE, THUMBNAIL_SIZE)
	end)
	const resolved = if ok and typeof(content) == "string" then content else ""
	self.Thumbnails[avatarId] = resolved
	return resolved
end

function BotController:SetMember(gameId: number, record: Member)
	const previous = self.Members[gameId]
	if previous and self.ByUserId[previous.UserId] == gameId then
		self.ByUserId[previous.UserId] = nil
	end
	self.Members[gameId] = record
	self.ByUserId[record.UserId] = gameId

	if previous and (previous.UserId ~= record.UserId or previous.AvatarId ~= record.AvatarId) then
		self:ViewOf(gameId).Rebuild = true
	end
	self.Changed:Fire(gameId)
end

function BotController:RemoveMember(gameId: number)
	const member = self.Members[gameId]
	if member and self.ByUserId[member.UserId] == gameId then
		self.ByUserId[member.UserId] = nil
	end
	self.Members[gameId] = nil
	self:ClearModel(gameId)
	self.Views[gameId] = nil
	self.Changed:Fire(gameId)
end

function BotController:ViewOf(gameId: number): View
	const existing = self.Views[gameId]
	if existing then
		return existing
	end

	const view: View = {
		GameID = gameId,
		Buffer = {},
		Model = nil,
		Root = nil,
		Animator = nil,
		Tracks = {},
		Playing = nil,
		Hold = nil,
		WeaponID = 0,
		Weapon = nil,
		Dead = true,
		Fresh = true,
		Rebuild = false,
	}
	self.Views[gameId] = view
	return view
end

function BotController:ClearModel(gameId: number)
	const view = self.Views[gameId]
	if not view then
		return
	end

	if view.Model then
		view.Model:Destroy()
	end
	view.Model = nil
	view.Root = nil
	view.Animator = nil
	view.Tracks = {}
	view.Playing = nil
	view.Hold = nil
	view.Weapon = nil
	view.WeaponID = 0
end

function BotController:Push(packet: BotNet.Frames)
	for _, frame in packet.Bots do
		if not self.Members[frame.GameID] then
			continue
		end

		const view = self:ViewOf(frame.GameID)
		const buffer = view.Buffer
		const last = buffer[#buffer]
		if last and packet.TimeStamp <= last.Time then
			continue
		end

		table.insert(buffer, {
			Time = packet.TimeStamp,
			Position = frame.Position,
			LookAt = frame.LookAt,
			State = frame.State,
			MoveDir = frame.MoveDir,
			WeaponID = frame.WeaponID,
		})
		while #buffer > MAX_SAMPLES do
			table.remove(buffer, 1)
		end
	end
end

local function pick(override: string?, fallback: string): string
	return if override and override ~= "" then override else fallback
end

local function loadTrack(animator: Animator, id: string?, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack?
	if not id or id == "" then
		return nil
	end

	const animation = Instance.new("Animation")
	animation.AnimationId = id
	const ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not ok or not track then
		return nil
	end
	track.Priority = priority
	track.Looped = looped
	return track
end

function BotController:LoadTracks(view: View, gunName: string?)
	const animator = view.Animator
	if not animator then
		return
	end

	for _, track in view.Tracks do
		track:Stop(0)
	end
	if view.Hold then
		view.Hold:Stop(0)
	end
	view.Tracks = {}
	view.Playing = nil
	view.Hold = nil

	const core = GetAnimations.Core()
	const movement = if gunName then GetAnimations.Movement(gunName) else nil
	const ids: { [string]: string? } = {
		Idle = pick(if movement then movement.Idle else nil, core.Idle),
		Run = pick(if movement then movement.RunForward else nil, core.Run),
		Fall = core.Fall,
	}
	for name, id in ids do
		const track = loadTrack(animator, id, Enum.AnimationPriority.Movement, true)
		if track then
			view.Tracks[name] = track
		end
	end

	const pose = if gunName then GetAnimations.CharacterPose(gunName) else nil
	if pose then
		view.Hold = loadTrack(animator, pose.Hold, Enum.AnimationPriority.Action, true)
		if view.Hold then
			view.Hold:Play(FADE_TIME)
		end
	end
end

function BotController:AttachWeapon(view: View, weaponId: number)
	if view.WeaponID == weaponId and view.Weapon then
		return
	end
	view.WeaponID = weaponId

	if view.Weapon then
		view.Weapon:Destroy()
		view.Weapon = nil
	end

	const model = view.Model
	const root = view.Root
	const gunData = GetGun.ByID(weaponId)
	if not model or not root or not gunData then
		self:LoadTracks(view, nil)
		return
	end

	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const weapons = if assets then assets:FindFirstChild("Weapons") else nil
	const asset = if weapons then weapons:FindFirstChild(gunData.DisplayName) else nil
	if asset and asset:IsA("Model") and asset.PrimaryPart then
		const visual = asset:Clone()
		const handle = visual.PrimaryPart :: BasePart
		for _, descendant in visual:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.Massless = true
				descendant.Anchored = false
				if descendant ~= handle then
					const weld = Instance.new("WeldConstraint")
					weld.Part0 = handle
					weld.Part1 = descendant
					weld.Parent = descendant
				end
			end
		end

		local motor = handle:FindFirstChild("BodyWeld")
		if not motor or not motor:IsA("Motor6D") then
			const created = Instance.new("Motor6D")
			created.Name = "BodyWeld"
			created.Parent = handle
			motor = created
		end
		const joint = motor :: Motor6D
		joint.Part0 = root
		joint.Part1 = handle

		visual.Name = gunData.DisplayName
		visual.Parent = model
		view.Weapon = visual
	end

	self:LoadTracks(view, gunData.DisplayName)
end

function BotController:Template(gameId: number): Instance?
	const member = self.Members[gameId]
	const rigs = ReplicatedStorage:FindFirstChild(BotSettings.RigFolder)
	return if member and rigs then rigs:FindFirstChild(`{member.UserId}_{member.AvatarId}`) else nil
end

function BotController:BuildModel(view: View): boolean
	const member = self.Members[view.GameID]
	const template = self:Template(view.GameID)
	if not member or not template or not template:IsA("Model") then
		return false
	end

	const model = template:Clone()
	model.Name = member.DisplayName
	model:SetAttribute(BotSettings.GameIDAttribute, view.GameID)

	const root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		model:Destroy()
		return false
	end
	root.Anchored = true

	const humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator: Animator? = nil
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		const existing = humanoid:FindFirstChildOfClass("Animator")
		if existing then
			animator = existing
		else
			const created = Instance.new("Animator")
			created.Parent = humanoid
			animator = created
		end
	end

	model.Parent = self.Folder
	view.Model = model
	view.Root = root
	view.Animator = animator
	view.Fresh = true
	view.WeaponID = -1
	view.Weapon = nil
	self.ModelAdded:Fire(view.GameID, model)
	return true
end

function BotController:Collapse(view: View)
	const model = view.Model
	if not model then
		return
	end

	for _, track in view.Tracks do
		track:Stop(0)
	end
	if view.Hold then
		view.Hold:Stop(0)
	end

	model:SetAttribute(BotSettings.GameIDAttribute, nil)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Name ~= "BodyWeld" then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanQuery = false
			descendant.CanCollide = descendant.Name ~= "HumanoidRootPart" and descendant:FindFirstAncestorOfClass("Accessory") == nil
		elseif descendant:IsA("BillboardGui") or descendant:IsA("Highlight") then
			descendant.Enabled = false
		end
	end

	view.Model = nil
	view.Root = nil
	view.Animator = nil
	view.Tracks = {}
	view.Playing = nil
	view.Hold = nil
	view.Weapon = nil
	view.WeaponID = 0

	task.delay(BotSettings.CorpseSeconds, function()
		model:Destroy()
	end)
end

local function sample(buffer: { Sample }, at: number): (Sample?, Sample?, number)
	local before: Sample? = nil
	local after: Sample? = nil
	for _, entry in buffer do
		if entry.Time <= at then
			before = entry
		else
			after = entry
			break
		end
	end

	if before and after then
		const span = after.Time - before.Time
		return before, after, if span > 0 then math.clamp((at - before.Time) / span, 0, 1) else 0
	end
	return before or after, nil, 0
end

function BotController:Animate(view: View, current: Sample)
	local wanted = "Idle"
	if current.State == "Jumping" then
		wanted = "Fall"
	elseif current.MoveDir.Magnitude > RUN_THRESHOLD then
		wanted = "Run"
	end

	if wanted == "Run" then
		const run = view.Tracks.Run
		if run then
			const pace = current.MoveDir.Magnitude * BotSettings.ChaseSpeed / BotSettings.WalkSpeed
			run:AdjustSpeed(math.clamp(pace, MIN_RUN_SPEED, MAX_RUN_SPEED))
		end
	end

	if view.Playing == wanted then
		return
	end

	const previous = if view.Playing then view.Tracks[view.Playing] else nil
	if previous then
		previous:Stop(FADE_TIME)
	end
	const track = view.Tracks[wanted] or view.Tracks.Idle
	if track then
		track:Play(FADE_TIME)
	end
	view.Playing = wanted
end

local function extrapolate(buffer: { Sample }, at: number): Vector3?
	const count = #buffer
	const last = buffer[count]
	const previous = buffer[count - 1]
	if not last or not previous or last.State == "Dead" then
		return nil
	end

	const span = last.Time - previous.Time
	if span <= 0 then
		return nil
	end
	const ahead = math.min(at - last.Time, MAX_EXTRAPOLATION)
	if ahead <= 0 then
		return nil
	end
	return last.Position + (last.Position - previous.Position) / span * ahead
end

function BotController:Render(dt: number)
	const at = workspace:GetServerTimeNow() - BotSettings.InterpolationDelay
	const turn = 1 - math.exp(-BotSettings.TurnSpeed * dt)
	for gameId, view in self.Views do
		const before, after, alpha = sample(view.Buffer, at)
		if not before then
			continue
		end

		const latest = after or before
		if latest.State == "Dead" then
			if not view.Dead then
				view.Dead = true
				self:Collapse(view)
			end
			continue
		end

		if view.Rebuild and self:Template(gameId) then
			view.Rebuild = false
			if not view.Dead then
				self:ClearModel(gameId)
			end
		end

		if view.Dead or not view.Model or not view.Model.Parent then
			if view.Model and not view.Model.Parent then
				self:ClearModel(gameId)
			end
			if not self:BuildModel(view) then
				continue
			end
			view.Dead = false
		end

		const position = if after
			then before.Position:Lerp(after.Position, alpha)
			else extrapolate(view.Buffer, at) or before.Position
		const lookAt = if after then before.LookAt:Lerp(after.LookAt, alpha) else before.LookAt
		const flat = Vector3.new(lookAt.X, position.Y, lookAt.Z)
		const root = view.Root
		if root then
			local rotation = root.CFrame.Rotation
			if (flat - position).Magnitude > 0.01 then
				const goal = CFrame.lookAt(position, flat).Rotation
				rotation = if view.Fresh then goal else rotation:Lerp(goal, turn)
			end
			root.CFrame = CFrame.new(position) * rotation
			view.Fresh = false
		end

		self:AttachWeapon(view, latest.WeaponID)
		self:Animate(view, latest)
	end
end

BotController:OnInit(function(self)
	self:Setup()

	const net = self.Libs.Net.Bot
	net.Roster:onAdded(function(gameId, record)
		self:SetMember(gameId, record)
	end)
	net.Roster:onChanged(function(gameId, record)
		self:SetMember(gameId, record)
	end)
	net.Roster:onRemoved(function(gameId)
		self:RemoveMember(gameId)
	end)

	net.Frames:onClient(function(packet: BotNet.Frames)
		self:Push(packet)
	end)
end)

BotController:OnStart(function(self)
	RunService.RenderStepped:Connect(function(dt: number)
		self:Render(dt)
	end)
end)

return BotController
