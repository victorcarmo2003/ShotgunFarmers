--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local OptionsCatalog = require(ReplicatedStorage.shared.Options.OptionsCatalog)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Crosshair = require(StarterPlayer.StarterPlayerScripts.client.Weapon.Crosshair)
local OptionsScreen = require(StarterPlayer.StarterPlayerScripts.client.Options.OptionsScreen)

const DEBOUNCE_SECONDS = 0.5
const CAPTURE_GUARD_SECONDS = 0.15

const OptionsController = Modux.Controller("OptionsController", {
	Require = {
		"GameStateController",
		"InputController",
		"MatchmakingController",
		"MenuEffectsController",
		"ProfileController",
		"UnlockCameraController",
	},
	Priority = 380,
})

function OptionsController:Setup()
	self.Values = Vide.source({}) :: Vide.Source<{ [string]: number }>
	self.Keys = Vide.source({}) :: Vide.Source<{ [string]: string }>
	self.Opened = Vide.source(false) :: Vide.Source<boolean>
	self.Capturing = Vide.source(nil) :: Vide.Source<string?>
	self.CaptureGuard = false :: boolean
	self.CaptureConnection = nil :: RBXScriptConnection?
	self.Dirty = {} :: { [string]: number }
	self.Tokens = {} :: { [string]: number }
	self.Unmount = nil :: (() -> ())?
end

function OptionsController:Get(id: string): number
	const stored = self.Values()[id]
	if stored ~= nil then
		return stored
	end

	const slider = OptionsCatalog.FindSlider(id)
	if slider then
		const field = slider.ProfileField
		if field then
			const source = (self.Dependencies.ProfileController :: any)[field] :: () -> number
			return source()
		end
		return slider.Default
	end

	const choice = OptionsCatalog.ChoiceById[id]
	return if choice then choice.Default else 0
end

function OptionsController:Fraction(slider: OptionsCatalog.Slider): number
	return OptionsCatalog.ToFraction(slider, self:Get(slider.Id))
end

function OptionsController:ChoiceIndex(choice: OptionsCatalog.Choice): number
	return math.clamp(math.round(self:Get(choice.Id)), 1, #choice.Options)
end

function OptionsController:ToggleCrouch(): boolean
	return self:Get("ToggleCrouch") >= 2
end

function OptionsController:KeyName(id: string): string
	const keybind = OptionsCatalog.KeybindById[id]
	return self.Keys()[id] or (if keybind then keybind.Default else "")
end

function OptionsController:SetLocal(id: string, value: number)
	const values = table.clone(self.Values())
	values[id] = value
	self.Values(values)
end

function OptionsController:Flush(id: string)
	const value = self.Dirty[id]
	if value == nil then
		return
	end

	self.Dirty[id] = nil
	self.Libs.Net.Options.SetSetting:fireServer({ Id = id, Value = value })
end

function OptionsController:FlushAll()
	for id in table.clone(self.Dirty) do
		self:Flush(id)
	end
end

function OptionsController:Queue(id: string, value: number)
	self.Dirty[id] = value
	const token = (self.Tokens[id] or 0) + 1
	self.Tokens[id] = token

	task.delay(DEBOUNCE_SECONDS, function()
		if self.Tokens[id] == token then
			self:Flush(id)
		end
	end)
end

function OptionsController:SetSlider(id: string, fraction: number)
	const slider = OptionsCatalog.FindSlider(id)
	if not slider then
		return
	end

	const value = OptionsCatalog.Clamp(slider, OptionsCatalog.FromFraction(slider, fraction))
	self:SetLocal(id, value)
	self:Queue(id, value)
end

function OptionsController:StepChoice(id: string, direction: number)
	const choice = OptionsCatalog.ChoiceById[id]
	if not choice then
		return
	end

	const count = #choice.Options
	const index = (self:ChoiceIndex(choice) - 1 + direction) % count + 1
	self:SetLocal(id, index)
	self.Dirty[id] = index
	self:Flush(id)
end

function OptionsController:ApplyKeys()
	const overrides: { [string]: Enum.KeyCode } = {}
	for _, keybind in OptionsCatalog.Keybinds do
		const keyCode = OptionsCatalog.ParseKey(self:KeyName(keybind.Id))
		if keyCode then
			overrides[keybind.Id] = keyCode
		end
	end

	self.Dependencies.InputController:SetOverrides(overrides)
end

function OptionsController:SendKey(id: string, name: string)
	self.Libs.Net.Options.SetKeybind:fireServer({ Id = id, Key = name })
end

function OptionsController:Assign(id: string, name: string)
	const current = self:KeyName(id)
	if current == name then
		return
	end

	const keys = table.clone(self.Keys())
	const changed: { [string]: string } = {}

	for _, other in OptionsCatalog.Keybinds do
		if other.Id ~= id and self:KeyName(other.Id) == name then
			changed[other.Id] = current
		end
	end
	changed[id] = name

	for changedId, keyName in changed do
		keys[changedId] = keyName
		self:SendKey(changedId, keyName)
	end

	self.Keys(keys)
	self:ApplyKeys()
end

function OptionsController:Clear(id: string)
	const keybind = OptionsCatalog.KeybindById[id]
	if keybind then
		self:Assign(id, keybind.Default)
	end
end

function OptionsController:EndCapture()
	const connection = self.CaptureConnection
	if connection then
		connection:Disconnect()
		self.CaptureConnection = nil
	end

	if Vide.read(self.Capturing) == nil then
		return
	end

	self.Capturing(nil)
	self.CaptureGuard = true
	task.delay(CAPTURE_GUARD_SECONDS, function()
		self.CaptureGuard = false
	end)
end

function OptionsController:BeginCapture(id: string)
	self:EndCapture()
	self.Capturing(id)

	self.CaptureConnection = UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		const keyCode = input.KeyCode
		if keyCode.Name == "Unknown" then
			return
		end

		if keyCode ~= Enum.KeyCode.Escape then
			self:Assign(id, keyCode.Name)
		end
		self:EndCapture()
	end)
end

function OptionsController:SetOpen(open: boolean)
	if self.Opened() == open then
		return
	end

	if not open then
		self:EndCapture()
		self:FlushAll()
	end

	self.Opened(open)
	self.Dependencies.InputController:SetContext(if open then "Menu" else "Gameplay")
	self.Dependencies.UnlockCameraController:SetMenu(open)
	if open then
		self.Dependencies.MenuEffectsController:Open("Options")
	else
		self.Dependencies.MenuEffectsController:Close("Options")
	end
end

function OptionsController:Toggle()
	if Vide.read(self.Capturing) ~= nil or self.CaptureGuard then
		return
	end

	if not self.Opened() and self.Dependencies.MenuEffectsController.Sources.Practice then
		return
	end

	self:SetOpen(not self.Opened())
end

function OptionsController:SliderRows(list: { OptionsCatalog.Slider }): { OptionsScreen.Slider }
	const rows: { OptionsScreen.Slider } = {}
	for _, slider in list do
		const value = self:Get(slider.Id)
		table.insert(rows, {
			Id = slider.Id,
			Label = slider.Label,
			Value = OptionsCatalog.ToFraction(slider, value),
			Display = OptionsCatalog.Display(slider, value),
		})
	end
	return rows
end

function OptionsController:CrosshairConfig(): Crosshair.Config
	return Crosshair.Resolve(function(id: string): number
		return self:Get(id)
	end)
end

function OptionsController:ApplyPreset(presetId: string)
	const preset = OptionsCatalog.CrosshairPresetById[presetId]
	if not preset then
		return
	end

	const values = table.clone(self.Values())
	for _, id in OptionsCatalog.CrosshairIds() do
		const slider = OptionsCatalog.SliderById[id]
		const choice = OptionsCatalog.ChoiceById[id]
		const default = if slider then slider.Default elseif choice then choice.Default else 0
		const value = preset.Values[id] or default
		values[id] = value
		self.Dirty[id] = value
	end

	self.Values(values)
	self:FlushAll()
end

function OptionsController:CrosshairRow(entry: OptionsCatalog.CrosshairEntry): OptionsScreen.CrosshairRow?
	if entry.Kind == "Preset" then
		const preset = OptionsCatalog.CrosshairPresetById[entry.Id]
		if not preset then
			return nil
		end
		return {
			Kind = "Preset",
			Id = entry.Id,
			Label = preset.Label,
			Value = 0,
			Display = "",
			Text = "APPLY",
		}
	end

	if entry.Kind == "Slider" then
		const slider = OptionsCatalog.SliderById[entry.Id]
		if not slider then
			return nil
		end
		const value = self:Get(entry.Id)
		return {
			Kind = "Slider",
			Id = entry.Id,
			Label = slider.Label,
			Value = OptionsCatalog.ToFraction(slider, value),
			Display = OptionsCatalog.Display(slider, value),
			Text = "",
		}
	end

	const choice = OptionsCatalog.ChoiceById[entry.Id]
	if not choice then
		return nil
	end
	return {
		Kind = "Choice",
		Id = entry.Id,
		Label = choice.Label,
		Value = 0,
		Display = "",
		Text = choice.Options[self:ChoiceIndex(choice)],
	}
end

function OptionsController:CrosshairSections(): { OptionsScreen.CrosshairSection }
	const sections: { OptionsScreen.CrosshairSection } = {}
	for _, section in OptionsCatalog.CrosshairSections do
		const rows: { OptionsScreen.CrosshairRow } = {}
		for _, entry in section.Entries do
			const row = self:CrosshairRow(entry)
			if row then
				table.insert(rows, row)
			end
		end
		table.insert(sections, { Label = section.Label, Rows = rows })
	end
	return sections
end

function OptionsController:Mount()
	const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	self.Unmount = Vide.mount(function()
		return Vide.create("ScreenGui")({
			Name = "OptionsUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 20,

			OptionsScreen({
				Visible = self.Opened,
				Sliders = function()
					return self:SliderRows(OptionsCatalog.Sliders)
				end,
				AudioSliders = function()
					return self:SliderRows(OptionsCatalog.AudioSliders)
				end,
				Choices = function()
					const rows: { OptionsScreen.Choice } = {}
					for _, choice in OptionsCatalog.Choices do
						table.insert(rows, {
							Id = choice.Id,
							Label = choice.Label,
							Value = choice.Options[self:ChoiceIndex(choice)],
						})
					end
					return rows
				end,
				Keybinds = function()
					const rows: { OptionsScreen.Keybind } = {}
					for _, keybind in OptionsCatalog.Keybinds do
						table.insert(rows, {
							Id = keybind.Id,
							Label = keybind.Label,
							Key = OptionsCatalog.KeyLabel(self:KeyName(keybind.Id)),
						})
					end
					return rows
				end,
				CrosshairSections = function()
					return self:CrosshairSections()
				end,
				CrosshairPreview = function()
					return self:CrosshairConfig()
				end,
				OnPreset = function(id: string)
					self:ApplyPreset(id)
				end,
				Capturing = self.Capturing,
				OnSlider = function(id: string, fraction: number)
					self:SetSlider(id, fraction)
				end,
				OnSliderEnd = function(id: string)
					self:Flush(id)
				end,
				OnChoice = function(id: string, direction: number)
					self:StepChoice(id, direction)
				end,
				OnRebind = function(id: string)
					self:BeginCapture(id)
				end,
				OnClear = function(id: string)
					self:Clear(id)
				end,
				OnClose = function()
					self:SetOpen(false)
				end,
				ShowLeave = function()
					return self.Dependencies.GameStateController:IsInMatch()
				end,
				LeaveText = function()
					return if self.Dependencies.MatchmakingController.State() == "Teleporting"
						then "LEAVING..."
						else "LEAVE MATCH"
				end,
				OnLeave = function()
					self.Dependencies.MatchmakingController:ReturnToLobby()
				end,
			}),
		})
	end, playerGui)
end

OptionsController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Options.State:onClient(function(state)
		Vide.batch(function()
			self.Values(state.Settings)
			self.Keys(state.Keybinds)
		end)
		self:ApplyKeys()
	end)
end)

OptionsController:OnStart(function(self)
	self.Dependencies.InputController
		:Bind({ Name = "Options", Key = Enum.KeyCode.M, Priority = 10 })
		.OnPress(function()
			self:Toggle()
		end)

	self:ApplyKeys()

	task.spawn(function()
		self:Mount()
	end)
end)

return OptionsController
