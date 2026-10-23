--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Announcement = require(StarterPlayer.StarterPlayerScripts.client.Shop.Announcement)

const SHOW_SECONDS = 4
const FADE_SECONDS = 0.4
const FADE_STEP = 0.03
const DISPLAY_ORDER = 12

const NO_REPLY = "No response"

local function answerOf(ok: boolean, reply: any): (boolean, string)
	if not ok or typeof(reply) ~= "table" then
		return false, NO_REPLY
	end

	const answer = reply :: { Accepted: boolean, Reason: string }
	return answer.Accepted, answer.Reason
end

const ShopController = Modux.Controller("ShopController", { Priority = 300 })

function ShopController:Setup()
	self.Message = Vide.source("") :: Vide.Source<string>
	self.Alpha = Vide.source(0) :: Vide.Source<number>
	self.Token = 0 :: number
end

function ShopController:BuySkin(id: string): (boolean, string)
	const ok, reply = self.Libs.Net.Shop.BuySkin:request({ Id = id })
	return answerOf(ok, reply)
end

function ShopController:RedeemCode(code: string): (boolean, string)
	const ok, reply = self.Libs.Net.Shop.RedeemCode:request({ Code = string.sub(code, 1, 24) })
	return answerOf(ok, reply)
end

function ShopController:EquipSkin(id: string, equip: boolean): (boolean, string)
	const ok, reply = self.Libs.Net.Shop.EquipSkin:request({ Id = id, Equip = equip })
	return answerOf(ok, reply)
end

function ShopController:Fade(from: number, to: number, token: number)
	const steps = math.max(1, math.floor(FADE_SECONDS / FADE_STEP))
	for index = 1, steps do
		if self.Token ~= token then
			return
		end
		self.Alpha(from + (to - from) * index / steps)
		task.wait(FADE_STEP)
	end
end

function ShopController:Show(message: string)
	self.Token += 1
	const token = self.Token
	self.Message(message)

	task.spawn(function()
		self:Fade(self.Alpha(), 1, token)
		task.wait(SHOW_SECONDS)
		if self.Token == token then
			self:Fade(1, 0, token)
		end
	end)
end

function ShopController:Mount()
	Vide.mount(function()
		return Vide.create("ScreenGui")({
			Name = "AnnouncementUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = DISPLAY_ORDER,

			Announcement({
				Message = self.Message,
				Alpha = self.Alpha,
			}),
		})
	end, Players.LocalPlayer:WaitForChild("PlayerGui"))
end

ShopController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Shop.Announce:onClient(function(payload)
		self:Show(payload.Message)
	end)
end)

ShopController:OnStart(function(self)
	self:Mount()
end)

return ShopController
