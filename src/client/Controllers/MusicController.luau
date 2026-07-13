local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)

local MusicController = Modux.Controller("MusicController")

-- Crossfade entre uma faixa e a próxima -- evita tanto o silêncio quanto o corte seco
-- que um Ended cru (sem fade) daria.
local FADE_TIME = 2
local CROSSFADE_TWEEN = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Linear)

local function getMusicFolder(): Folder
	local holder = SoundService:FindFirstChild("Music") :: Folder?
	if not holder then
		holder = Instance.new("Folder")
		holder.Name = "Music"
		holder.Parent = SoundService
	end
	return holder :: Folder
end

-- Fisher-Yates -- reembaralhada a cada volta completa da playlist, pra sessões longas
-- não caírem sempre na mesma ordem.
local function shuffle(list: { Sound })
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
end

-- Toca a próxima faixa da playlist com fade-in, enquanto apaga (fade-out + Destroy) a
-- que estava tocando -- nunca há silêncio nem sobreposição abrupta entre as duas.
-- O volume-alvo de cada faixa é o Volume já configurado no Sound original (em
-- ReplicatedStorage.Assets.Musics), então o balanceamento feito no Studio é respeitado.
MusicController.PlayNext = function(self)
	if #self.Playlist == 0 then
		return
	end

	self.PlaylistIndex += 1
	if self.PlaylistIndex > #self.Playlist then
		self.PlaylistIndex = 1
		shuffle(self.Playlist)
	end

	local template = self.Playlist[self.PlaylistIndex]
	local targetVolume = template.Volume

	local sound = template:Clone()
	sound.Volume = 0
	-- O loop/avanço é gerenciado por nós via Ended -- looped cru nunca dispararia esse evento.
	sound.Looped = false
	sound.Parent = self.MusicFolder
	sound:Play()
	TweenService:Create(sound, CROSSFADE_TWEEN, { Volume = targetVolume }):Play()

	local previous = self.CurrentSound
	self.CurrentSound = sound

	if previous then
		local fadeOut = TweenService:Create(previous, CROSSFADE_TWEEN, { Volume = 0 })
		fadeOut.Completed:Once(function()
			previous:Destroy()
		end)
		fadeOut:Play()
	end

	if self.EndedConnection then
		self.EndedConnection:Disconnect()
	end
	self.EndedConnection = sound.Ended:Once(function()
		self:PlayNext()
	end)
end

MusicController:OnInit(function(self)
	self.MusicFolder = getMusicFolder() :: Folder
	self.Playlist = {} :: { Sound }
	self.PlaylistIndex = 0 :: number
	self.CurrentSound = nil :: Sound?
	self.EndedConnection = nil :: RBXScriptConnection?
end)

MusicController:OnStart(function(self)
	local musicsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Musics")

	for _, instance in musicsFolder:GetChildren() do
		if instance:IsA("Sound") then
			table.insert(self.Playlist, instance)
		end
	end

	if #self.Playlist == 0 then
		warn("[MusicController] Nenhuma Sound encontrada em ReplicatedStorage.Assets.Musics")
		return
	end

	shuffle(self.Playlist)
	self:PlayNext()
end)

return MusicController
