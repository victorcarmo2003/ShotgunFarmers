--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Bullet = {
	Part: BasePart,
	StartPos: Vector3,
	EndPos: Vector3,
	StartTime: number,
	ArrivedAt: number?,
}

const BULLET_SPEED = 1200
const BULLET_LINGER_TIME = 3

const ProjectileController = Modux.Controller("ProjectileController", { Priority = 480 })

function ProjectileController:Setup()
	self.AllBullets = {} :: { Bullet }
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

local function bulletTemplate(): BasePart?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const template = if assets then assets:FindFirstChild("bullet_trail") else nil
	return if template and template:IsA("BasePart") then template else nil
end

function ProjectileController:Shoot(startPos: Vector3, endPos: Vector3)
	const template = bulletTemplate()
	if not template then
		return
	end

	const part = template:Clone()
	part.CFrame = CFrame.lookAt(startPos, endPos)
	part.Parent = bulletFolder()

	table.insert(self.AllBullets, {
		Part = part,
		StartPos = startPos,
		EndPos = endPos,
		StartTime = os.clock(),
	})
end

function ProjectileController:Step()
	const now = os.clock()

	for index = #self.AllBullets, 1, -1 do
		const bullet = self.AllBullets[index]
		const distance = (bullet.EndPos - bullet.StartPos).Magnitude
		const duration = if distance > 0 then distance / BULLET_SPEED else 0
		const alpha = if duration > 0 then math.clamp((now - bullet.StartTime) / duration, 0, 1) else 1

		if alpha < 1 then
			bullet.Part.Position = bullet.StartPos:Lerp(bullet.EndPos, alpha)
			continue
		end

		bullet.Part.Position = bullet.EndPos

		const arrivedAt = bullet.ArrivedAt or now
		bullet.ArrivedAt = arrivedAt
		if now - arrivedAt >= BULLET_LINGER_TIME then
			bullet.Part:Destroy()
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
