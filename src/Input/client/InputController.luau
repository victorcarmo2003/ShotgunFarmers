--!strict
local ContextActionService = game:GetService("ContextActionService")
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Context = "Gameplay" | "Menu"

export type Binding = {
	Name: string,
	Key: Enum.KeyCode | Enum.UserInputType,
	TouchButton: boolean?,
	Priority: number?,
	Position: UDim2?,
}

export type Handle = {
	OnPress: (callback: () -> ()) -> Handle,
	OnRelease: (callback: () -> ()) -> Handle,
	Unbind: () -> (),
	_press: { () -> () },
	_release: { () -> () },
}

const InputController = Modux.Controller("InputController", { Priority = 900 })

function InputController:Setup()
	self.Context = "Gameplay" :: Context
	self.Handles = {} :: { [string]: Handle }
	self.Listeners = {} :: { (Context) -> () }
end

function InputController:Dispatch(name: string, state: Enum.UserInputState): Enum.ContextActionResult
	const handle = self.Handles[name]
	if not handle then
		return Enum.ContextActionResult.Pass
	end

	const callbacks = if state == Enum.UserInputState.Begin
		then handle._press
		elseif state == Enum.UserInputState.End then handle._release
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

	ContextActionService:BindActionAtPriority(
		binding.Name,
		function(name: string, state: Enum.UserInputState): Enum.ContextActionResult
			return self:Dispatch(name, state)
		end,
		binding.TouchButton or false,
		binding.Priority or 0,
		binding.Key
	)

	if binding.Position then
		ContextActionService:SetPosition(binding.Name, binding.Position)
	end

	return handle
end

function InputController:Unbind(name: string)
	if self.Handles[name] == nil then
		return
	end
	self.Handles[name] = nil
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
