--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local DamageNumber = require(StarterPlayer.StarterPlayerScripts.client.Hit.DamageNumber)

type Entry = {
	Amount: Vide.Source<number>,
	Headshot: Vide.Source<boolean>,
	Killed: Vide.Source<boolean>,
	Pop: Vide.Source<number>,
	Fading: Vide.Source<boolean>,
	Attachment: Attachment,
	Unmount: () -> (),
	LastAt: number,
	Token: number,
}

export type Dealt = {
	TargetID: number,
	Position: Vector3,
	Amount: number,
	Headshot: boolean,
	Killed: boolean,
}

const MERGE_WINDOW = 0.6
const LIFETIME = 0.8
const FADE_TIME = 0.35
const HEAD_OFFSET = Vector3.new(0, 3, 0)
const RISE = Vector3.new(0, 1.5, 0)
const JITTER = 0.6
const SIZE = UDim2.fromOffset(110, 44)
const MAX_DISTANCE = 250

const DamageNumberController = Modux.Controller("DamageNumberController", { Require = { "HitController" }, Priority = 440 })

function DamageNumberController:Setup()
	self.Entries = {} :: { [number]: Entry }
end

function DamageNumberController:Mount(entry: Entry)
	const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	entry.Unmount = Vide.mount(function()
		return Vide.create("BillboardGui")({
			Name = "DamageNumber",
			Adornee = entry.Attachment,
			Size = SIZE,
			AlwaysOnTop = true,
			LightInfluence = 0,
			MaxDistance = MAX_DISTANCE,
			ResetOnSpawn = false,

			DamageNumber({
				Amount = entry.Amount,
				Headshot = entry.Headshot,
				Killed = entry.Killed,
				Pop = entry.Pop,
				Fading = entry.Fading,
			}),
		})
	end, playerGui)
end

function DamageNumberController:Create(data: Dealt): Entry
	const attachment = Instance.new("Attachment")
	attachment.Name = "DamageNumber"
	attachment.Parent = workspace.Terrain
	const jitter = Vector3.new((math.random() - 0.5) * JITTER, 0, (math.random() - 0.5) * JITTER)
	attachment.WorldPosition = data.Position + HEAD_OFFSET + jitter

	const entry: Entry = {
		Amount = Vide.source(data.Amount),
		Headshot = Vide.source(data.Headshot),
		Killed = Vide.source(data.Killed),
		Pop = Vide.source(0),
		Fading = Vide.source(false),
		Attachment = attachment,
		Unmount = function() end,
		LastAt = os.clock(),
		Token = 0,
	}
	self:Mount(entry)
	return entry
end

function DamageNumberController:Expire(targetID: number, entry: Entry)
	entry.Fading(true)
	TweenService:Create(entry.Attachment, TweenInfo.new(FADE_TIME), {
		Position = entry.Attachment.Position + RISE,
	}):Play()

	task.delay(FADE_TIME, function()
		entry.Unmount()
		entry.Attachment:Destroy()
		if self.Entries[targetID] == entry then
			self.Entries[targetID] = nil
		end
	end)
end

function DamageNumberController:Schedule(targetID: number, entry: Entry)
	entry.Token += 1
	const token = entry.Token
	task.delay(LIFETIME, function()
		if entry.Token == token then
			self:Expire(targetID, entry)
		end
	end)
end

function DamageNumberController:Show(data: Dealt)
	self.Dependencies.HitController:Mark(data.Headshot, data.Killed)
	const now = os.clock()
	local entry = self.Entries[data.TargetID]
	if entry and not entry.Fading() and now - entry.LastAt <= MERGE_WINDOW then
		entry.Amount(entry.Amount() + data.Amount)
		entry.Headshot(entry.Headshot() or data.Headshot)
		entry.Killed(entry.Killed() or data.Killed)
		entry.Pop(entry.Pop() + 1)
		entry.LastAt = now
	else
		entry = self:Create(data)
		self.Entries[data.TargetID] = entry
	end

	self:Schedule(data.TargetID, entry :: Entry)
end

DamageNumberController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Hit.Dealt:onClient(function(data)
		self:Show(data)
	end)
end)

return DamageNumberController
