--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const FADE_TIME = 2
const CROSSFADE_TWEEN = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Linear)

const MusicController = Modux.Controller("MusicController", { Priority = 300 })

local function musicFolder(): Folder
	const existing = SoundService:FindFirstChild("Music")
	if existing and existing:IsA("Folder") then
		return existing
	end

	const folder = Instance.new("Folder")
	folder.Name = "Music"
	folder.Parent = SoundService
	return folder
end

local function musicTemplates(): { Sound }
	const list: { Sound } = {}
	for _, child in ReplicatedStorage.Assets.Musics:GetChildren() do
		if child:IsA("Sound") then
			table.insert(list, child)
		end
	end

	return list
end

local function shuffle(list: { Sound })
	for i = #list, 2, -1 do
		const j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
end

function MusicController:Setup()
	self.MusicFolder = musicFolder() :: Folder
	self.Playlist = {} :: { Sound }
	self.PlaylistIndex = 0 :: number
	self.CurrentSound = nil :: Sound?
	self.EndedConnection = nil :: RBXScriptConnection?
end

function MusicController:PlayNext()
	if #self.Playlist == 0 then
		return
	end

	self.PlaylistIndex += 1
	if self.PlaylistIndex > #self.Playlist then
		self.PlaylistIndex = 1
		shuffle(self.Playlist)
	end

	const template = self.Playlist[self.PlaylistIndex]
	const targetVolume = template.Volume

	const sound = template:Clone()
	sound.Volume = 0
	sound.Looped = false
	sound.Parent = self.MusicFolder
	sound:Play()
	TweenService:Create(sound, CROSSFADE_TWEEN, { Volume = targetVolume }):Play()

	const previous = self.CurrentSound
	self.CurrentSound = sound

	if previous then
		const fadeOut = TweenService:Create(previous, CROSSFADE_TWEEN, { Volume = 0 })
		fadeOut.Completed:Once(function()
			previous:Destroy()
		end)
		fadeOut:Play()
	end

	const connection = self.EndedConnection
	if connection then
		connection:Disconnect()
	end
	self.EndedConnection = sound.Ended:Once(function()
		self:PlayNext()
	end)
end

MusicController:OnInit(function(self)
	self:Setup()
end)

MusicController:OnStart(function(self)
	self.Playlist = musicTemplates()
	if #self.Playlist == 0 then
		warn("[MusicController] nenhuma Sound em ReplicatedStorage.Assets.Musics")
		return
	end

	shuffle(self.Playlist)
	self:PlayNext()
end)

return MusicController
