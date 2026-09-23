--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local QuickZone = require(ReplicatedStorage.Packages.QuickZone)
local Modux = require(ServerScriptService.server.Modux)

const MIN_HEIGHT = 8

const PlayerGroup = QuickZone.Group.players()

const Zone = Modux.Component("Zone", { Tag = "Zone", Require = { "ZoneService" } })

function Zone:Setup()
	const instance = self.Instance

	self.Part = (if instance:IsA("BasePart") then instance else nil) :: BasePart?

	self.Area = nil :: QuickZone.Zone?
	self.Observer = nil :: QuickZone.Observer<Player>?
	self.Disconnect = nil :: (() -> ())?
end

function Zone:Observe()
	const part = self.Part
	if not part then
		warn(`[Zone] {self.Instance:GetFullName()} tem a tag "Zone" mas nao e uma BasePart`)
		return
	end

	const size = Vector3.new(part.Size.X, math.max(part.Size.Y, MIN_HEIGHT), part.Size.Z)
	const cframe = part.CFrame * CFrame.new(0, (size.Y - part.Size.Y) / 2, 0)

	const observer = QuickZone.Observer.new({ groups = { PlayerGroup } })
	self.Observer = observer

	const area = QuickZone.Zone.new({
		cframe = cframe,
		size = size,
		shape = "Block",
	})
	area:attach(observer)
	self.Area = area

	self.Disconnect = observer:observePlayer(function(player: Player): (() -> ())?
		self.Dependencies.ZoneService:Enter(player, part.Name)

		return function()
			self.Dependencies.ZoneService:Leave(player, part.Name)
		end
	end)
end

Zone:OnInit(function(self)
	self:Setup()
	self:Observe()
end)

Zone:OnDestroy(function(self)
	if self.Disconnect then
		self.Disconnect()
		self.Disconnect = nil
	end

	if self.Area then
		self.Area:destroy()
		self.Area = nil
	end

	if self.Observer then
		self.Observer:destroy()
		self.Observer = nil
	end
end)

return Zone
