--!strict
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local GameState = require(ReplicatedStorage.shared.Match.GameState)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Context = "Gameplay" | "Menu"

export type Binding = {
	Name: string,
	Key: Enum.KeyCode | Enum.UserInputType,
	TouchButton: boolean?,
	Priority: number?,
	Position: UDim2?,
	Requires: GameState.Capability?,
}

export type Handle = {
	OnPress: (callback: () -> ()) -> Handle,
	OnRelease: (callback: () -> ()) -> Handle,
	Unbind: () -> (),
	Requires: GameState.Capability?,
	_press: { () -> () },
	_release: { () -> () },
}

const InputController = Modux.Controller("InputController", {
	Require = { "GameStateController" },
	Priority = 900,
})

function InputController:Setup()
	self.Context = "Gameplay" :: Context
	self.Handles = {} :: { [string]: Handle }
	self.Listeners = {} :: { (Context) -> () }
	self.Bindings = {} :: { [string]: Binding }
	self.Overrides = {} :: { [string]: Enum.KeyCode }
end

function InputController:Dispatch(name: string, state: Enum.UserInputState): Enum.ContextActionResult
	const handle = self.Handles[name]
	if not handle then
		return Enum.ContextActionResult.Pass
	end

	if state == Enum.UserInputState.Begin and handle.Requires then
		if self.Context == "Menu" then
			return Enum.ContextActionResult.Pass
		end
		if not self.Dependencies.GameStateController:Can(handle.Requires) then
			return Enum.ContextActionResult.Pass
		end
	end

	const callbacks = if state == Enum.UserInputState.Begin
		then handle._press
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then handle._release
		else nil

	if callbacks then
		for _, callback in callbacks do
			task.spawn(callback)
		end
	end

	return Enum.ContextActionResult.Sink
end

function InputController:Bind(binding: Binding): Handle
	const handle = {
		_press = {},
		_release = {},
		Requires = binding.Requires,
	} :: Handle

	handle.OnPress = function(callback: () -> ()): Handle
		table.insert(handle._press, callback)
		return handle
	end

	handle.OnRelease = function(callback: () -> ()): Handle
		table.insert(handle._release, callback)
		return handle
	end

	handle.Unbind = function()
		self:Unbind(binding.Name)
	end

	self.Handles[binding.Name] = handle
	self.Bindings[binding.Name] = binding
	self:Register(binding.Name)

	return handle
end

function InputController:KeyOf(name: string): (Enum.KeyCode | Enum.UserInputType)?
	const binding = self.Bindings[name]
	if not binding then
		return nil
	end

	return self.Overrides[name] or binding.Key
end

function InputController:Register(name: string)
	const binding = self.Bindings[name]
	if not binding then
		return
	end

	ContextActionService:BindActionAtPriority(
		name,
		function(actionName: string, state: Enum.UserInputState): Enum.ContextActionResult
			return self:Dispatch(actionName, state)
		end,
		binding.TouchButton or false,
		binding.Priority or 0,
		self.Overrides[name] or binding.Key
	)

	if binding.Position then
		ContextActionService:SetPosition(name, binding.Position)
	end
end

function InputController:Rebind(name: string, key: Enum.KeyCode?)
	self.Overrides[name] = key

	if self.Bindings[name] then
		ContextActionService:UnbindAction(name)
		self:Register(name)
	end
end

function InputController:SetOverrides(overrides: { [string]: Enum.KeyCode })
	const names: { [string]: boolean } = {}
	for name in self.Overrides do
		names[name] = true
	end
	for name in overrides do
		names[name] = true
	end

	for name in names do
		if self.Overrides[name] ~= overrides[name] then
			self:Rebind(name, overrides[name])
		end
	end
end

function InputController:Unbind(name: string)
	if self.Handles[name] == nil then
		return
	end
	self.Handles[name] = nil
	self.Bindings[name] = nil
	ContextActionService:UnbindAction(name)
end

function InputController:OnContextChange(callback: (Context) -> ())
	table.insert(self.Listeners, callback)
end

function InputController:SetContext(context: Context)
	if self.Context == context then
		return
	end
	self.Context = context
	for _, listener in self.Listeners do
		task.spawn(listener, context)
	end
end

InputController:OnInit(function(self)
	self:Setup()
end)

return InputController
