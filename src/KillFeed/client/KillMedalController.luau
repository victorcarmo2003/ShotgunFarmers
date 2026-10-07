--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local KillMedal = require(StarterPlayer.StarterPlayerScripts.client.KillFeed.KillMedal)
local MedalSettings = require(ReplicatedStorage.shared.KillFeed.MedalSettings)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WeaponSounds = require(ReplicatedStorage.shared.Weapon.WeaponSounds)

const KillMedalController = Modux.Controller("KillMedalController", { Priority = 410 })

function KillMedalController:Setup()
	self.Text = Vide.source("") :: Vide.Source<string>
	self.SubText = Vide.source("") :: Vide.Source<string>
	self.Color = Vide.source(MedalSettings.HeadshotColor) :: Vide.Source<Color3>
	self.Elapsed = Vide.source(MedalSettings.Duration) :: Vide.Source<number>
	self.Connection = nil :: RBXScriptConnection?
	self.Unmount = nil :: (() -> ())?
end

type Title = { Text: string, Color: Color3 }

local function titleFor(headshot: boolean, multi: number): Title?
	if multi >= MedalSettings.RampageMulti then
		return { Text = MedalSettings.RampageText, Color = MedalSettings.RampageColor }
	end

	const text = MedalSettings.MultiTexts[multi]
	if multi >= 2 and text then
		return { Text = text, Color = MedalSettings.MultiColor }
	end

	if headshot then
		return { Text = MedalSettings.HeadshotText, Color = MedalSettings.HeadshotColor }
	end

	return nil
end

function KillMedalController:Stop()
	const connection = self.Connection
	if connection then
		connection:Disconnect()
		self.Connection = nil
	end
end

function KillMedalController:Run()
	self:Stop()
	self.Elapsed(0)
	self.Connection = RunService.Heartbeat:Connect(function(dt)
		const elapsed = self.Elapsed() + dt
		self.Elapsed(elapsed)
		if elapsed >= MedalSettings.Duration then
			self:Stop()
		end
	end)
end

function KillMedalController:PlaySound(headshot: boolean, multi: number)
	WeaponSounds.Play2D(MedalSettings.KillSound)

	if headshot then
		if WeaponSounds.Template(MedalSettings.HeadshotSound) then
			WeaponSounds.Play2D(MedalSettings.HeadshotSound)
		end
	end

	if multi >= 2 and WeaponSounds.Template(MedalSettings.MultiSound) then
		WeaponSounds.Play2D(MedalSettings.MultiSound)
	end
end

function KillMedalController:Show(headshot: boolean, multi: number, streak: number)
	self:PlaySound(headshot, multi)

	const title = titleFor(headshot, multi)
	if not title then
		return
	end

	self.Text(title.Text)
	self.Color(title.Color)
	self.SubText(if streak >= MedalSettings.StreakMin then string.format(MedalSettings.StreakFormat, streak) else "")
	self:Run()
end

function KillMedalController:Mount()
	const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	self.Unmount = Vide.mount(function()
		return Vide.create("ScreenGui")({
			Name = "KillMedalUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = MedalSettings.DisplayOrder,

			KillMedal({
				Text = self.Text,
				SubText = self.SubText,
				Color = self.Color,
				Elapsed = self.Elapsed,
			}),
		})
	end, playerGui)
end

KillMedalController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.KillFeed.Medal:onClient(function(data)
		self:Show(data.Headshot, data.Multi, data.Streak)
	end)
end)

KillMedalController:OnStart(function(self)
	self:Mount()
end)

return KillMedalController
