--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local GetThumbnail = require(ReplicatedStorage.shared.Utils.GetThumbnail)
local KillFeed = require(StarterPlayer.StarterPlayerScripts.client.KillFeed.KillFeed)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Entry = KillFeed.Entry

const ENTRY_LIFETIME = 6
const MAX_ENTRIES = 5

const KillFeedController = Modux.Controller("KillFeedController", { Priority = 420 })

function KillFeedController:Setup()
	self.Entries = Vide.source({}) :: Vide.Source<{ Entry }>
	self.Thumbnails = {} :: { [Player]: string }
end

local function playerFromGameID(id: number): Player?
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("GameID") == id then
			return player
		end
	end

	return nil
end

function KillFeedController:Thumbnail(player: Player): string
	const cached = self.Thumbnails[player]
	if cached then
		return cached
	end

	const content = GetThumbnail.HeadShot(player)
	const resolved = content or ""
	self.Thumbnails[player] = resolved
	return resolved
end

function KillFeedController:Forget(entry: Entry)
	const current = table.clone(self.Entries())
	const index = table.find(current, entry)
	if not index then
		return
	end

	table.remove(current, index)
	self.Entries(current)
end

function KillFeedController:Push(shooter: Player, victim: Player, gunName: string, isHeadshot: boolean)
	const gunData = GetGun.ByName(gunName)

	const entry: Entry = {
		ShooterName = shooter.DisplayName,
		ShooterImage = self:Thumbnail(shooter),
		VictimName = victim.DisplayName,
		VictimImage = self:Thumbnail(victim),
		GunName = (gunData and gunData.DisplayName) or gunName,
		GunImage = (gunData and gunData.ImageID) or "",
		IsHeadshot = isHeadshot,
	}

	const current = table.clone(self.Entries())
	table.insert(current, 1, entry)
	while #current > MAX_ENTRIES do
		table.remove(current)
	end

	self.Entries(current)

	task.delay(ENTRY_LIFETIME, function()
		self:Forget(entry)
	end)
end

KillFeedController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.KillFeed.Kill:onClient(function(data)
		task.spawn(function()
			const shooter = playerFromGameID(data.ShooterID)
			const victim = playerFromGameID(data.VictimID)
			if not shooter or not victim then
				return
			end

			self:Push(shooter, victim, data.GunName, data.IsHeadshot)
		end)
	end)
end)

return KillFeedController
