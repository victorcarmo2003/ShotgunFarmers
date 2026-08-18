local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Modux = require(ReplicatedStorage.Shared.Modux)
local GetGun = require(ReplicatedStorage.Shared.Utils.GetGun)

export type ShootRequest = {
	startPos: Vector3,
	endPos: Vector3,
	ammoType: GetGun.AmmoType,
}

export type BulletData = ShootRequest & {
	instance: BasePart,
	startTime: number,
	arrivedAt: number?,
}

local BULLET_SPEED = 1200

local BULLET_LINGER_TIME = 3

local ProjectileController = Modux.Controller("ProjectileController")
type Self = typeof(ProjectileController)
ProjectileController.AllBullets = {} :: { [number]: BulletData }

local function getBulletFolder(): Folder
	local folder = workspace:FindFirstChild("Bullets") :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Bullets"
		folder.Parent = workspace
	end
	return folder :: Folder
end

ProjectileController.Shoot = function(self: Self, request: ShootRequest)
	local bulletTrail = ReplicatedStorage.Assets.bullet_trail
	local clonedBullet = bulletTrail:Clone() :: BasePart
	clonedBullet.CFrame = CFrame.lookAt(request.startPos, request.endPos)
	clonedBullet.Parent = getBulletFolder()

	local data: BulletData = {
		instance = clonedBullet,
		startPos = request.startPos,
		endPos = request.endPos,
		ammoType = request.ammoType,
		startTime = os.clock(),
	}

	table.insert(self.AllBullets, data)
end

ProjectileController:OnInit(function(self)
	self:Cleanup(RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for i = #self.AllBullets, 1, -1 do
			local bullet = self.AllBullets[i]
			local distance = (bullet.endPos - bullet.startPos).Magnitude
			local duration = if distance > 0 then distance / BULLET_SPEED else 0
			local alpha = if duration > 0 then math.clamp((now - bullet.startTime) / duration, 0, 1) else 1

			if alpha >= 1 then
				bullet.instance.Position = bullet.endPos
				if not bullet.arrivedAt then
					bullet.arrivedAt = now
				end
				if now - bullet.arrivedAt >= BULLET_LINGER_TIME then
					bullet.instance:Destroy()
					table.remove(self.AllBullets, i)
				end
			else
				bullet.instance.Position = bullet.startPos:Lerp(bullet.endPos, alpha)
			end
		end
	end))
end)

return ProjectileController
