local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetThumbnail = require(ReplicatedStorage.Shared.Utils.GetThumbnail)
local GetGun = require(ReplicatedStorage.Shared.Utils.GetGun)
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local Modux = require(game.ReplicatedStorage.Shared.Modux)

local KillFeedController = Modux.Controller("KillFeedController")
type Self = typeof(KillFeedController)

local ENTRY_LIFETIME = 6

local MAX_ENTRIES = 5

export type KillFeedEntryData = {
	LayoutOrder: number,
	ShooterName: string,
	ShooterImage: string,
	VictimName: string,
	VictimImage: string,
	GunName: string,
	GunImage: string,
	IsHeadshot: boolean,
}

local function getPlayerFromGameID(id: number): Player?
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("GameID") == id then
			return player
		end
	end
	return nil
end

KillFeedController:OnInit(function(self)
	self.Scope = Fusion.scoped(Fusion)
	self.Entries = self.Scope:Value({}) :: Fusion.Value<{ [number]: KillFeedEntryData }>
	self.NextEntryID = 0 :: number
	self.ThumbnailCache = {} :: { [Player]: string }
end)

KillFeedController.GetCachedThumbnail = function(self: Self, player: Player): string
	local cached = self.ThumbnailCache[player]
	if cached then
		return cached
	end
	local content = GetThumbnail.HeadShot(player)
	local resolved = content or ""
	self.ThumbnailCache[player] = resolved
	return resolved
end

KillFeedController.PushEntry = function(
	self: Self,
	shooter: Player,
	victim: Player,
	gunName: string,
	isHeadshot: boolean,
	persistent: boolean?
)
	self.NextEntryID += 1
	local id = self.NextEntryID

	local gunData = GetGun:GetByName(gunName :: any)

	local entries = table.clone(Fusion.peek(self.Entries))
	entries[id] = {
		LayoutOrder = -id,
		ShooterName = shooter.DisplayName,
		ShooterImage = self:GetCachedThumbnail(shooter),
		VictimName = victim.DisplayName,
		VictimImage = self:GetCachedThumbnail(victim),
		GunName = (gunData and gunData.DisplayName) or gunName,
		GunImage = (gunData and gunData.ImageID) or "",
		IsHeadshot = isHeadshot,
	} :: KillFeedEntryData

	local count = 0
	local oldestID: number? = nil
	for entryID in entries do
		count += 1
		if not oldestID or entryID < oldestID then
			oldestID = entryID
		end
	end
	if count > MAX_ENTRIES and oldestID then
		entries[oldestID] = nil
	end

	self.Entries:set(entries)

	if persistent then
		return
	end

	task.delay(ENTRY_LIFETIME, function()
		local current = table.clone(Fusion.peek(self.Entries))
		current[id] = nil
		self.Entries:set(current)
	end)
end

KillFeedController:OnStart(function(self)
	task.spawn(function()
		self:PushEntry(self.LocalPlayer, self.LocalPlayer, "Shotgun", true, true)
	end)

	self.Network.Packages.KillFeed:on(function(data)
		task.spawn(function()
			local shooter = getPlayerFromGameID(data.ShooterID)
			local victim = getPlayerFromGameID(data.VictimID)
			if not shooter or not victim then
				return
			end
			self:PushEntry(shooter, victim, data.GunName, data.IsHeadshot)
		end)
	end)
end)

return KillFeedController
