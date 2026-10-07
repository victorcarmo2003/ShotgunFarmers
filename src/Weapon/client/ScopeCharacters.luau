--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScopeSettings = require(ReplicatedStorage.shared.Weapon.ScopeSettings)

type Pair = {
	Real: Motor6D,
	Clone: Motor6D,
}

type Entry = {
	Player: Player,
	Character: Model?,
	Clone: Model?,
	RealRoot: BasePart?,
	CloneRoot: BasePart?,
	Humanoid: Humanoid?,
	Pairs: { Pair },
	Connections: { RBXScriptConnection },
	CharacterConnections: { RBXScriptConnection },
	Pending: boolean,
	Generation: number,
}

export type ScopeCharacters = {
	Step: () -> (),
	Destroy: () -> (),
}

local function motorKey(motor: Motor6D): string?
	const part0 = motor.Part0
	const part1 = motor.Part1
	if not part0 or not part1 then
		return nil
	end
	return `{part0.Name}/{motor.Name}/{part1.Name}`
end

local function strip(clone: Model)
	for _, descendant in clone:GetDescendants() do
		if
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Sound")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("BillboardGui")
			or descendant:IsA("SurfaceGui")
			or descendant:IsA("Animator")
			or descendant:IsA("AnimationController")
		then
			descendant:Destroy()
		end
	end
end

local function disconnectAll(connections: { RBXScriptConnection })
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function new(worldModel: WorldModel): ScopeCharacters
	const entries: { [Player]: Entry } = {}
	const globalConnections: { RBXScriptConnection } = {}
	local destroyed = false

	local function destroyClone(entry: Entry)
		if entry.Clone then
			entry.Clone:Destroy()
		end
		entry.Clone = nil
		entry.RealRoot = nil
		entry.CloneRoot = nil
		entry.Humanoid = nil
		table.clear(entry.Pairs)
	end

	local function buildClone(entry: Entry)
		destroyClone(entry)

		const character = entry.Character
		if not character or not character.Parent then
			return
		end

		const realRoot = character:FindFirstChild("HumanoidRootPart")
		const humanoid = character:FindFirstChildOfClass("Humanoid")
		if not realRoot or not realRoot:IsA("BasePart") or not humanoid then
			return
		end

		const wasArchivable = character.Archivable
		character.Archivable = true
		const clone = character:Clone()
		character.Archivable = wasArchivable
		if not clone then
			return
		end

		strip(clone)

		const cloneRoot = clone:FindFirstChild("HumanoidRootPart")
		if not cloneRoot or not cloneRoot:IsA("BasePart") then
			clone:Destroy()
			return
		end

		const cloneMotors: { [string]: Motor6D } = {}
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = false
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.CastShadow = false
			elseif descendant:IsA("Motor6D") then
				const key = motorKey(descendant)
				if key then
					cloneMotors[key] = descendant
				end
			elseif descendant:IsA("Humanoid") then
				descendant.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				descendant.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			end
		end
		cloneRoot.Anchored = true

		for _, descendant in character:GetDescendants() do
			if descendant:IsA("Motor6D") then
				const key = motorKey(descendant)
				const counterpart = if key then cloneMotors[key] else nil
				if counterpart then
					table.insert(entry.Pairs, { Real = descendant, Clone = counterpart })
				end
			end
		end

		entry.Clone = clone
		entry.RealRoot = realRoot
		entry.CloneRoot = cloneRoot
		entry.Humanoid = humanoid
	end

	local function scheduleRebuild(entry: Entry)
		if entry.Pending or destroyed then
			return
		end
		entry.Pending = true
		const generation = entry.Generation
		task.defer(function()
			entry.Pending = false
			if destroyed or entry.Generation ~= generation then
				return
			end
			buildClone(entry)
		end)
	end

	local function clearCharacter(entry: Entry)
		entry.Generation += 1
		entry.Pending = false
		disconnectAll(entry.CharacterConnections)
		destroyClone(entry)
		entry.Character = nil
	end

	local function setCharacter(entry: Entry, character: Model)
		clearCharacter(entry)
		entry.Character = character

		table.insert(
			entry.CharacterConnections,
			character.ChildAdded:Connect(function()
				scheduleRebuild(entry)
			end)
		)
		table.insert(
			entry.CharacterConnections,
			character.ChildRemoved:Connect(function()
				scheduleRebuild(entry)
			end)
		)

		const generation = entry.Generation
		task.spawn(function()
			character:WaitForChild("HumanoidRootPart", ScopeSettings.CharacterTimeout)
			character:WaitForChild("Humanoid", ScopeSettings.CharacterTimeout)
			if destroyed or entry.Generation ~= generation then
				return
			end
			buildClone(entry)
		end)
	end

	local function addPlayer(player: Player)
		if player == Players.LocalPlayer or entries[player] or destroyed then
			return
		end

		const entry: Entry = {
			Player = player,
			Character = nil,
			Clone = nil,
			RealRoot = nil,
			CloneRoot = nil,
			Humanoid = nil,
			Pairs = {},
			Connections = {},
			CharacterConnections = {},
			Pending = false,
			Generation = 0,
		}
		entries[player] = entry

		table.insert(
			entry.Connections,
			player.CharacterAdded:Connect(function(character)
				setCharacter(entry, character)
			end)
		)
		table.insert(
			entry.Connections,
			player.CharacterRemoving:Connect(function()
				clearCharacter(entry)
			end)
		)

		if player.Character then
			setCharacter(entry, player.Character)
		end
	end

	local function removePlayer(player: Player)
		const entry = entries[player]
		if not entry then
			return
		end
		entries[player] = nil
		clearCharacter(entry)
		disconnectAll(entry.Connections)
	end

	table.insert(globalConnections, Players.PlayerAdded:Connect(addPlayer))
	table.insert(globalConnections, Players.PlayerRemoving:Connect(removePlayer))
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end

	local function step()
		for _, entry in entries do
			const clone = entry.Clone
			const realRoot = entry.RealRoot
			const cloneRoot = entry.CloneRoot
			const humanoid = entry.Humanoid
			if not clone or not realRoot or not cloneRoot or not humanoid then
				continue
			end

			if not realRoot.Parent or humanoid.Health <= 0 then
				if clone.Parent then
					clone.Parent = nil
				end
				continue
			end

			if clone.Parent ~= worldModel then
				clone.Parent = worldModel
			end

			cloneRoot.CFrame = realRoot.CFrame
			for _, pair in entry.Pairs do
				pair.Clone.Transform = pair.Real.Transform
			end
		end
	end

	local function destroy()
		destroyed = true
		disconnectAll(globalConnections)
		for player in entries do
			removePlayer(player)
		end
	end

	return {
		Step = step,
		Destroy = destroy,
	}
end

return {
	new = new,
	MotorKey = motorKey,
	Strip = strip,
}
