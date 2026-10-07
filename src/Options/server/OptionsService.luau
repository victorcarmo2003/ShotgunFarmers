--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local OptionsCatalog = require(ReplicatedStorage.shared.Options.OptionsCatalog)
local Modux = require(ServerScriptService.server.Modux)

const WINDOW_SECONDS = 1
const WINDOW_LIMIT = 60
const VOLUME_STEP = 0.01

const OptionsService = Modux.Service("OptionsService", {
	Require = { "NetService", "PlayerService", "ProfileService" },
	Priority = 620,
})

function OptionsService:Setup()
	self.Windows = {} :: { [Player]: { Start: number, Count: number } }
end

function OptionsService:Allow(player: Player): boolean
	const now = os.clock()
	local window = self.Windows[player]
	if not window or now - window.Start >= WINDOW_SECONDS then
		window = { Start = now, Count = 0 }
		self.Windows[player] = window
	end

	window.Count += 1
	return window.Count <= WINDOW_LIMIT
end

function OptionsService:SendState(player: Player)
	const profile = self.Dependencies.ProfileService:Get(player)
	if not profile or not self.Dependencies.NetService:IsReady(player) then
		return
	end

	self.Libs.Net.Options.State:fireClient(player, {
		Settings = profile.Settings(),
		Keybinds = profile.Keybinds(),
	})
end

function OptionsService:SetSetting(player: Player, id: string, value: number)
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	if not profile or value ~= value then
		return
	end

	const audio = OptionsCatalog.AudioSliderById[id]
	if audio and audio.ProfileField then
		const clamped = math.round(OptionsCatalog.Clamp(audio, value) / VOLUME_STEP) * VOLUME_STEP
		profiles:Update(player, { [audio.ProfileField] = math.clamp(clamped, 0, 1) } :: any)
		return
	end

	const slider = OptionsCatalog.SliderById[id]
	if slider then
		const settings = table.clone(profile.Settings())
		settings[id] = OptionsCatalog.Clamp(slider, value)
		profiles:Update(player, { Settings = settings })
		return
	end

	const choice = OptionsCatalog.ChoiceById[id]
	if choice then
		const index = math.round(value)
		if index < 1 or index > #choice.Options then
			return
		end

		const settings = table.clone(profile.Settings())
		settings[id] = index
		profiles:Update(player, { Settings = settings })
	end
end

function OptionsService:SetKeybind(player: Player, id: string, key: string)
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	const keybind = OptionsCatalog.KeybindById[id]
	if not profile or not keybind then
		return
	end

	const keyCode = OptionsCatalog.ParseKey(key)
	if not keyCode or keyCode == Enum.KeyCode.Escape then
		return
	end

	const keybinds = table.clone(profile.Keybinds())
	keybinds[id] = if keyCode.Name == keybind.Default then nil else keyCode.Name
	profiles:Update(player, { Keybinds = keybinds })
end

OptionsService:OnInit(function(self)
	self:Setup()

	self.Dependencies.ProfileService.Loaded:Connect(function(player)
		self:SendState(player)
	end)

	self.Dependencies.NetService.ClientReady:Connect(function(player)
		self:SendState(player)
	end)

	self.Libs.Net.Options.SetSetting:onServer(function(request, player)
		if self:Allow(player) then
			self:SetSetting(player, request.Id, request.Value)
		end
	end)

	self.Libs.Net.Options.SetKeybind:onServer(function(request, player)
		if self:Allow(player) then
			self:SetKeybind(player, request.Id, request.Key)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.Windows[player] = nil
	end)
end)

return OptionsService
