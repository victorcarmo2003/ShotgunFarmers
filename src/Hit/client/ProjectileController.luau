--!strict
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Bullet = {
	Part: BasePart,
	Template: string,
	StartPos: Vector3,
	EndPos: Vector3,
	StartTime: number,
	Speed: number,
	Linger: number,
	ArrivedAt: number?,
}

export type TracerPool = { Free: { BasePart }, Count: number, Linger: number }

const BULLET_SPEED = 1200
const BULLET_LINGER_TIME = 3
const DEFAULT_TRACER = "bullet_trail"
const MAX_TRACERS_PER_TEMPLATE = 48
const BEAM_LINGER = 0.03

const FLAME_PUFFS = 2
const FLAME_LIFETIME = 0.3
const FLAME_START_SIZE = 0.6
const FLAME_END_SIZE = 3.5
const FLAME_COLORS = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 110, 30), Color3.fromRGB(230, 50, 20) }

const ProjectileController = Modux.Controller("ProjectileController", { Priority = 480 })

function ProjectileController:Setup()
	self.AllBullets = {} :: { Bullet }
	self.Pools = {} :: { [string]: TracerPool }
end

local function bulletFolder(): Folder
	const existing = workspace:FindFirstChild("Bullets")
	if existing and existing:IsA("Folder") then
		return existing
	end

	const folder = Instance.new("Folder")
	folder.Name = "Bullets"
	folder.Parent = workspace
	return folder
end

local function tracerTemplate(name: string): BasePart?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return nil
	end

	const folder: Instance? = if name == DEFAULT_TRACER then assets else assets:FindFirstChild("VFX")
	const template = if folder then folder:FindFirstChild(name) else nil
	return if template and template:IsA("BasePart") then template else nil
end

local function trailLinger(part: BasePart): number
	local linger = BEAM_LINGER
	for _, descendant in part:GetDescendants() do
		if descendant:IsA("Trail") then
			linger = math.max(linger, descendant.Lifetime)
		end
	end
	return linger
end

local function setTrails(part: BasePart, enabled: boolean)
	for _, descendant in part:GetDescendants() do
		if descendant:IsA("Trail") then
			if enabled then
				descendant:Clear()
			end
			descendant.Enabled = enabled
		end
	end
end

function ProjectileController:Acquire(name: string): (BasePart?, number)
	local pool = self.Pools[name]
	if not pool then
		const template = tracerTemplate(name)
		if not template then
			return nil, 0
		end
		const created: TracerPool = {
			Free = {},
			Count = 0,
			Linger = if name == DEFAULT_TRACER then BULLET_LINGER_TIME else trailLinger(template),
		}
		pool = created
		self.Pools[name] = created
	end

	const free = table.remove(pool.Free)
	if free then
		return free, pool.Linger
	end

	if pool.Count >= MAX_TRACERS_PER_TEMPLATE then
		return nil, 0
	end

	const template = tracerTemplate(name)
	if not template then
		return nil, 0
	end

	pool.Count += 1
	const part = template:Clone()
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part, pool.Linger
end

function ProjectileController:Release(bullet: Bullet)
	const part = bullet.Part
	setTrails(part, false)
	part.Parent = nil

	const pool = self.Pools[bullet.Template]
	if pool then
		table.insert(pool.Free, part)
	else
		part:Destroy()
	end
end

function ProjectileController:Shoot(startPos: Vector3, endPos: Vector3, tracer: string?, speed: number?)
	local name = tracer or DEFAULT_TRACER
	local part, linger = self:Acquire(name)
	if not part and name ~= DEFAULT_TRACER then
		name = DEFAULT_TRACER
		part, linger = self:Acquire(name)
	end
	if not part then
		return
	end

	setTrails(part, false)
	part.CFrame = CFrame.lookAt(startPos, endPos)
	part.Parent = bulletFolder()
	setTrails(part, true)

	table.insert(self.AllBullets, {
		Part = part,
		Template = name,
		StartPos = startPos,
		EndPos = endPos,
		StartTime = os.clock(),
		Speed = speed or BULLET_SPEED,
		Linger = linger,
	})
end

function ProjectileController:Flame(origin: Vector3, direction: Vector3, range: number, spread: number)
	const folder = bulletFolder()
	const tweenInfo = TweenInfo.new(FLAME_LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	for _ = 1, FLAME_PUFFS do
		const angleX = math.rad((math.random() - 0.5) * spread)
		const angleY = math.rad((math.random() - 0.5) * spread)
		const heading = (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(angleX, angleY, 0)).LookVector
		const finish = origin + heading * range * (0.6 + math.random() * 0.4)

		const puff = Instance.new("Part")
		puff.Name = "Flame"
		puff.Shape = Enum.PartType.Ball
		puff.Material = Enum.Material.Neon
		puff.Color = FLAME_COLORS[math.random(1, #FLAME_COLORS)]
		puff.Transparency = 0.2
		puff.Size = Vector3.one * FLAME_START_SIZE
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.CanTouch = false
		puff.CastShadow = false
		puff.Position = origin
		puff.Parent = folder

		TweenService:Create(puff, tweenInfo, {
			Position = finish,
			Size = Vector3.one * FLAME_END_SIZE,
			Transparency = 1,
		}):Play()
		Debris:AddItem(puff, FLAME_LIFETIME + 0.05)
	end
end

function ProjectileController:Step()
	const now = os.clock()

	for index = #self.AllBullets, 1, -1 do
		const bullet = self.AllBullets[index]
		const distance = (bullet.EndPos - bullet.StartPos).Magnitude
		const duration = if distance > 0 then distance / bullet.Speed else 0
		const alpha = if duration > 0 then math.clamp((now - bullet.StartTime) / duration, 0, 1) else 1

		if alpha < 1 then
			bullet.Part.Position = bullet.StartPos:Lerp(bullet.EndPos, alpha)
			continue
		end

		bullet.Part.Position = bullet.EndPos

		const arrivedAt = bullet.ArrivedAt or now
		bullet.ArrivedAt = arrivedAt
		if now - arrivedAt >= bullet.Linger then
			self:Release(bullet)
			table.remove(self.AllBullets, index)
		end
	end
end

ProjectileController:OnInit(function(self)
	self:Setup()
end)

ProjectileController:OnStart(function(self)
	RunService.Heartbeat:Connect(function()
		self:Step()
	end)
end)

return ProjectileController
