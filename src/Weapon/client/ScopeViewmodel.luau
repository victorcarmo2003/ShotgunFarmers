--!strict
local ScopeCharacters = require(script.Parent.ScopeCharacters)

type Pair = {
	Real: Motor6D,
	Clone: Motor6D,
}

export type ScopeViewmodel = {
	Build: (rig: Model) -> (),
	Clear: () -> (),
	SetVisible: (visible: boolean) -> (),
	Step: () -> (),
	Destroy: () -> (),
}

local function new(worldModel: WorldModel): ScopeViewmodel
	local clone: Model? = nil
	local realTorso: BasePart? = nil
	local cloneTorso: BasePart? = nil
	const pairs: { Pair } = {}

	local function clear()
		if clone then
			clone:Destroy()
		end
		clone = nil
		realTorso = nil
		cloneTorso = nil
		table.clear(pairs)
	end

	local function build(rig: Model)
		clear()

		const torso = rig:FindFirstChild("Torso")
		if not torso or not torso:IsA("BasePart") then
			return
		end

		const wasArchivable = rig.Archivable
		rig.Archivable = true
		const copy = rig:Clone()
		rig.Archivable = wasArchivable
		if not copy then
			return
		end

		ScopeCharacters.Strip(copy)

		const copyTorso = copy:FindFirstChild("Torso")
		if not copyTorso or not copyTorso:IsA("BasePart") then
			copy:Destroy()
			return
		end

		const motors: { [string]: Motor6D } = {}
		for _, descendant in copy:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = descendant == copyTorso
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.CastShadow = false
				descendant.LocalTransparencyModifier = 0
			elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
				descendant.LocalTransparencyModifier = 0
			elseif descendant:IsA("Motor6D") then
				const key = ScopeCharacters.MotorKey(descendant)
				if key then
					motors[key] = descendant
				end
			end
		end

		for _, descendant in rig:GetDescendants() do
			if descendant:IsA("Motor6D") then
				const key = ScopeCharacters.MotorKey(descendant)
				const counterpart = if key then motors[key] else nil
				if counterpart then
					table.insert(pairs, { Real = descendant, Clone = counterpart })
				end
			end
		end

		clone = copy
		realTorso = torso
		cloneTorso = copyTorso
	end

	local function step()
		const copy = clone
		const real = realTorso
		const copied = cloneTorso
		if not copy or not real or not copied or copy.Parent ~= worldModel then
			return
		end

		copied.CFrame = real.CFrame
		for _, pair in pairs do
			pair.Clone.Transform = pair.Real.Transform
		end
	end

	local function setVisible(visible: boolean)
		const copy = clone
		if not copy then
			return
		end

		if visible then
			if copy.Parent ~= worldModel then
				copy.Parent = worldModel
			end
			step()
		elseif copy.Parent then
			copy.Parent = nil
		end
	end

	return {
		Build = build,
		Clear = clear,
		SetVisible = setVisible,
		Step = step,
		Destroy = clear,
	}
end

return {
	new = new,
}
