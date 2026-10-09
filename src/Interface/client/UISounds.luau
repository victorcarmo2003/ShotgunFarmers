--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

export type Cue = "Hover" | "Click" | "Open" | "Error"

const NAMES: { [Cue]: string } = {
	Hover = "UIHover",
	Click = "UIClick",
	Open = "UIOpen",
	Error = "UIError",
}

const HOVER_COOLDOWN = 0.05

const warned: { [string]: boolean } = {}
local lastHover = 0

local function template(name: string): Sound?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const sounds = if assets then assets:FindFirstChild("Sounds") else nil
	const sound = if sounds then sounds:FindFirstChild(name) else nil
	if sound and sound:IsA("Sound") then
		return sound
	end

	if not warned[name] then
		warned[name] = true
		warn(`[UISounds] Assets.Sounds.{name} nao encontrado`)
	end
	return nil
end

const UISounds = {}

function UISounds.Play(cue: Cue)
	if cue == "Hover" then
		const now = os.clock()
		if now - lastHover < HOVER_COOLDOWN then
			return
		end
		lastHover = now
	end

	const sound = template(NAMES[cue])
	if sound then
		SoundService:PlayLocalSound(sound)
	end
end

return UISounds
