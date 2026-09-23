--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

type Snapshot = { Health: number, Armor: number, Stamina: number }

const MAX_HEALTH = 100

const NORMAL_SATURATION = 0.5
const DRAINED_SATURATION = -2
const DRAIN_BELOW = 0.5

const VitalController = Modux.Controller("VitalController", { Require = { "ColorCorrectionController" }, Priority = 800 })

function VitalController:Setup()
	self.Health = Vide.source(100) :: Vide.Source<number>
	self.Armor = Vide.source(0) :: Vide.Source<number>
	self.Stamina = Vide.source(100) :: Vide.Source<number>
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

VitalController:OnInit(function(self)
	self:Setup()

	const userId = Players.LocalPlayer.UserId

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

return VitalController
