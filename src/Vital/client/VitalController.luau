--!strict
local Players = game:GetService "Players"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"
local StarterGui = game:GetService "StarterGui"
local StarterPlayer = game:GetService "StarterPlayer"
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local DamageIndicator = require(StarterPlayer.StarterPlayerScripts.client.Vital.DamageIndicator)

type Snapshot = { Health: number, Armor: number, Stamina: number }
type DamageEntry = { From: Vector3, At: number }

const MAX_HEALTH = 100

const RESET_BIND_ATTEMPTS = 20
const RESET_BIND_INTERVAL = 0.5

const NORMAL_SATURATION = 0.5
const DRAINED_SATURATION = -2
const DRAIN_BELOW = 0.5

const INDICATOR_SECONDS = 1.2
const INDICATOR_MAX = 6
const FLASH_PER_DAMAGE = 0.025
const FLASH_MAX = 1
const FLASH_DECAY = 2.5
const LOW_HEALTH_BELOW = 0.35
const LOW_HEALTH_PULSE = 3
const INDICATOR_ORDER = 4

const VitalController =
	Modux.Controller("VitalController", { Require = { "ColorCorrectionController" }, Priority = 800 })

function VitalController:Setup()
	self.Health = Vide.source(100) :: Vide.Source<number>
	self.Armor = Vide.source(0) :: Vide.Source<number>
	self.Stamina = Vide.source(100) :: Vide.Source<number>
	self.ResetEvent = Instance.new("BindableEvent") :: BindableEvent
	self.DamageEntries = {} :: { DamageEntry }
	self.Hits = Vide.source({}) :: Vide.Source<{ DamageIndicator.Hit }>
	self.Flash = Vide.source(0) :: Vide.Source<number>
	self.LowHealth = Vide.source(0) :: Vide.Source<number>
end

function VitalController:OnDamaged(from: Vector3, amount: number)
	table.insert(self.DamageEntries, { From = from, At = os.clock() })
	while #self.DamageEntries > INDICATOR_MAX do
		table.remove(self.DamageEntries, 1)
	end
	self.Flash(math.min(self.Flash() + amount * FLASH_PER_DAMAGE, FLASH_MAX))
end

function VitalController:StepIndicators(deltaTime: number)
	const now = os.clock()
	const camera = workspace.CurrentCamera

	const hits: { DamageIndicator.Hit } = {}
	for index = #self.DamageEntries, 1, -1 do
		const entry = self.DamageEntries[index]
		const age = now - entry.At
		if age >= INDICATOR_SECONDS then
			table.remove(self.DamageEntries, index)
		elseif camera then
			const offset = entry.From - camera.CFrame.Position
			const right = offset:Dot(camera.CFrame.RightVector)
			const forward = offset:Dot(camera.CFrame.LookVector)
			table.insert(hits, { Angle = math.deg(math.atan2(right, forward)), Alpha = 1 - age / INDICATOR_SECONDS })
		end
	end

	if #hits > 0 or #self.Hits() > 0 then
		self.Hits(hits)
	end

	const flash = self.Flash()
	if flash > 0 then
		self.Flash(math.max(0, flash - FLASH_DECAY * deltaTime))
	end

	const percent = math.clamp(self.Health() / MAX_HEALTH, 0, 1)
	local low = 0
	if percent > 0 and percent < LOW_HEALTH_BELOW then
		const pulse = 0.75 + 0.25 * math.sin(now * LOW_HEALTH_PULSE)
		low = (1 - percent / LOW_HEALTH_BELOW) * pulse
	end
	if low ~= self.LowHealth() then
		self.LowHealth(low)
	end
end

function VitalController:MountIndicators()
	Vide.mount(function()
		return Vide.create("ScreenGui")({
			Name = "DamageIndicatorUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = INDICATOR_ORDER,

			DamageIndicator({
				Hits = self.Hits,
				Flash = self.Flash,
				LowHealth = self.LowHealth,
			}),
		})
	end, Players.LocalPlayer:WaitForChild("PlayerGui"))

	RunService.RenderStepped:Connect(function(deltaTime: number)
		self:StepIndicators(deltaTime)
	end)
end

local function saturationFor(health: number): number
	const percent = math.clamp(health / MAX_HEALTH, 0, 1)
	if percent >= DRAIN_BELOW then
		return NORMAL_SATURATION
	end

	return DRAINED_SATURATION + ((NORMAL_SATURATION - DRAINED_SATURATION) * (percent / DRAIN_BELOW))
end

function VitalController:Apply(snapshot: Snapshot)
	self.Health(snapshot.Health)
	self.Armor(snapshot.Armor)
	self.Stamina(snapshot.Stamina)
	self.Dependencies.ColorCorrectionController:SetSaturation(saturationFor(snapshot.Health))
end

function VitalController:Of(player: Player): Snapshot?
	return self.Libs.Net.Vital.Vitals:get(player.UserId)
end

function VitalController:BindReset()
	self.ResetEvent.Event:Connect(function()
		self.Libs.Net.Vital.RequestReset:fireServer()
	end)

	task.spawn(function()
		for _ = 1, RESET_BIND_ATTEMPTS do
			if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", self.ResetEvent) then
				return
			end
			task.wait(RESET_BIND_INTERVAL)
		end
	end)
end

VitalController:OnInit(function(self)
	self:Setup()
	self:BindReset()

	const userId = Players.LocalPlayer.UserId

	self.Libs.Net.Vital.Damaged:onClient(function(payload)
		self:OnDamaged(payload.From, payload.Amount)
	end)

	self.Libs.Net.Vital.Vitals:onAdded(function(id, record)
		if id == userId then
			self:Apply(record)
		end
	end)

	self.Libs.Net.Vital.Vitals:onChanged(function(id, record)
		if id == userId then
			self:Apply(record)
		end
	end)
end)

VitalController:OnStart(function(self)
	self:MountIndicators()
end)

return VitalController
