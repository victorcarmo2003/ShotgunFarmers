--!strict
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local GameModes = require(ReplicatedStorage.shared.Match.GameModes)
local Maps = require(ReplicatedStorage.shared.Match.Maps)
local MatchSettings = require(ReplicatedStorage.shared.Match.MatchSettings)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

const FFA_SPAWN_TAG = "FFASpawn"
const PLACEHOLDER_RIG = "Rig"
const PROPERTIES_FOLDER = "Properties"
const CLEARED_LIGHTING_CLASSES = { "Sky", "Atmosphere", "Clouds", "PostEffect" }
const PROPS_FOLDER = "Props"
const BOUNDARY_NAME = "Boundary"
const BOUNDARY_CORNERS = {
	Vector3.new(1, 1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, -1, -1),
}

type MatchConfig = { Map: string, Mode: string }

const EnvironmentService = Modux.Service("EnvironmentService", {
	Require = { "ServerRoleService" },
	Priority = 885,
})

function EnvironmentService:Setup()
	self.Root = nil :: Instance?
	self.IsReady = false :: boolean
	self.Ready = self.Libs.Signal.new() :: SignalLib.Signal<>
	self.MapChanged = self.Libs.Signal.new() :: SignalLib.Signal<string>
end

function EnvironmentService:GetRoot(): Instance?
	return self.Root
end

function EnvironmentService:OnReady(callback: () -> ())
	if self.IsReady then
		callback()
		return
	end

	self.Ready:Connect(callback)
end

function EnvironmentService:GetFFASpawns(): { BasePart }
	const spawns: { BasePart } = {}
	const root = self.Root
	if not root then
		return spawns
	end

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and CollectionService:HasTag(descendant, FFA_SPAWN_TAG) then
			table.insert(spawns, descendant)
		end
	end

	return spawns
end

function EnvironmentService:GetTeamSpawn(teamName: string): BasePart?
	const root = self.Root
	const folder = if root then root:FindFirstChild("TeamSpawn") else nil
	const part = if folder then folder:FindFirstChild(teamName) else nil
	return if part and part:IsA("BasePart") then part else nil
end

function EnvironmentService:GetLobbySlot(index: number): BasePart?
	const root = self.Root
	const folder = if root then root:FindFirstChild("CharacterPositions") else nil
	const part = if folder then folder:FindFirstChild(tostring(index)) else nil
	return if part and part:IsA("BasePart") then part else nil
end

function EnvironmentService:GetLobbyCamera(): BasePart?
	const root = self.Root
	const part = if root then root:FindFirstChild("CameraPosition1", true) else nil
	return if part and part:IsA("BasePart") then part else nil
end

function EnvironmentService:ValidateMap(mapName: string, source: Instance?, problems: { string })
	const map = Maps[mapName]
	const model = if source then source:FindFirstChild(mapName) else nil
	if not model then
		table.insert(problems, `mapa "{mapName}" nao existe em ServerStorage.Maps`)
		return
	end

	const lightingRoot = ServerStorage:FindFirstChild(MatchSettings.LightingFolderName)
	if not lightingRoot or not lightingRoot:FindFirstChild(map.Lighting) then
		table.insert(problems, `preset de lighting "{map.Lighting}" do mapa "{mapName}" nao existe`)
	end

	local supportsFFA = false
	local supportsTeams = false
	for _, modeName in map.Modes do
		const mode = GameModes.Modes[modeName]
		if mode and mode.Teams then
			supportsTeams = true
		elseif mode then
			supportsFFA = true
		end
	end

	if supportsFFA then
		local found = false
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and CollectionService:HasTag(descendant, FFA_SPAWN_TAG) then
				found = true
				break
			end
		end
		if not found then
			table.insert(problems, `mapa "{mapName}" sem nenhuma part com a tag {FFA_SPAWN_TAG}`)
		end
	end

	if supportsTeams then
		const folder = model:FindFirstChild("TeamSpawn")
		for _, teamName in MatchSettings.TeamNames do
			const part = if folder then folder:FindFirstChild(teamName) else nil
			if not part or not part:IsA("BasePart") then
				table.insert(problems, `mapa "{mapName}" sem TeamSpawn.{teamName}`)
			end
		end
	end
end

function EnvironmentService:Validate()
	const problems: { string } = {}

	const mapsFolder = ServerStorage:FindFirstChild("Maps")
	if not mapsFolder then
		table.insert(problems, "ServerStorage.Maps nao existe")
	end
	for mapName in Maps do
		self:ValidateMap(mapName, mapsFolder, problems)
	end

	const lobbyFolder = ServerStorage:FindFirstChild("Lobby")
	const lobby = if lobbyFolder then lobbyFolder:FindFirstChild(MatchSettings.LobbyModel) else nil
	if not lobby then
		table.insert(problems, `ServerStorage.Lobby.{MatchSettings.LobbyModel} nao existe`)
	else
		const positions = lobby:FindFirstChild("CharacterPositions")
		for index = 1, MatchSettings.LobbySlotCount do
			if not positions or not positions:FindFirstChild(tostring(index)) then
				table.insert(problems, `lobby sem CharacterPositions.{index}`)
			end
		end
		if not lobby:FindFirstChild("CameraPosition1", true) then
			table.insert(problems, "lobby sem CameraPosition1")
		end
	end

	const lightingRoot = ServerStorage:FindFirstChild(MatchSettings.LightingFolderName)
	if not lightingRoot or not lightingRoot:FindFirstChild(MatchSettings.LobbyLighting) then
		table.insert(problems, `preset de lighting "{MatchSettings.LobbyLighting}" do lobby nao existe`)
	end

	if #problems > 0 then
		warn(`[EnvironmentService] problemas de validacao:\n - {table.concat(problems, "\n - ")}`)
	end
end

function EnvironmentService:ApplyLighting(presetName: string)
	const lightingRoot = ServerStorage:FindFirstChild(MatchSettings.LightingFolderName)
	const preset = if lightingRoot then lightingRoot:FindFirstChild(presetName) else nil
	if not preset then
		warn(`[EnvironmentService] preset de lighting "{presetName}" nao encontrado`)
		return
	end

	for _, child in Lighting:GetChildren() do
		for _, className in CLEARED_LIGHTING_CLASSES do
			if child:IsA(className) then
				child:Destroy()
				break
			end
		end
	end

	for _, child in preset:GetChildren() do
		if child.Name ~= PROPERTIES_FOLDER then
			child:Clone().Parent = Lighting
		end
	end

	const properties = preset:FindFirstChild(PROPERTIES_FOLDER)
	if not properties then
		return
	end

	for _, value in properties:GetChildren() do
		if value:IsA("ValueBase") then
			const name = value.Name
			const propertyValue = (value :: any).Value
			const applied, reason = pcall(function()
				(Lighting :: any)[name] = propertyValue
			end)
			if not applied then
				warn(`[EnvironmentService] propriedade "{name}" invalida: {tostring(reason)}`)
			end
		end
	end
end

local function extentsOf(sources: { Instance }): (Vector3?, Vector3?)
	local low: Vector3? = nil
	local high: Vector3? = nil
	for _, source in sources do
		for _, part in source:GetDescendants() do
			if not part:IsA("BasePart") then
				continue
			end

			const half = part.Size / 2
			for _, corner in BOUNDARY_CORNERS do
				const point = part.CFrame:PointToWorldSpace(half * corner)
				low = if low then low:Min(point) else point
				high = if high then high:Max(point) else point
			end
		end
	end
	return low, high
end

local function boundaryWall(parent: Instance, center: Vector3, size: Vector3)
	const wall = Instance.new("Part")
	wall.Name = "Wall"
	wall.Anchored = true
	wall.CanCollide = true
	wall.CanQuery = false
	wall.CanTouch = false
	wall.CastShadow = false
	wall.Transparency = 1
	wall.Size = size
	wall.CFrame = CFrame.new(center)
	wall.Parent = parent
end

function EnvironmentService:BuildBoundary(root: Instance, mapName: string)
	const map = Maps[mapName]
	const props = root:FindFirstChild(PROPS_FOLDER)
	if not map or not map.Boundary or not props then
		return
	end

	const sources: { Instance } = {}
	for _, name in map.Boundary do
		const source = props:FindFirstChild(name)
		if source then
			table.insert(sources, source)
		else
			warn(`[EnvironmentService] Boundary "{name}" nao encontrado em {mapName}.Props`)
		end
	end

	const low, high = extentsOf(sources)
	if not low or not high then
		return
	end

	const padding = MatchSettings.BoundaryPadding
	const thickness = MatchSettings.BoundaryThickness
	const height = MatchSettings.BoundaryHeight
	const minX = low.X - padding - thickness / 2
	const maxX = high.X + padding + thickness / 2
	const minZ = low.Z - padding - thickness / 2
	const maxZ = high.Z + padding + thickness / 2
	const centerY = low.Y - MatchSettings.BoundaryDepth + height / 2
	const spanX = maxX - minX + thickness
	const spanZ = maxZ - minZ + thickness

	const folder = Instance.new("Folder")
	folder.Name = BOUNDARY_NAME
	boundaryWall(folder, Vector3.new(minX, centerY, (minZ + maxZ) / 2), Vector3.new(thickness, height, spanZ))
	boundaryWall(folder, Vector3.new(maxX, centerY, (minZ + maxZ) / 2), Vector3.new(thickness, height, spanZ))
	boundaryWall(folder, Vector3.new((minX + maxX) / 2, centerY, minZ), Vector3.new(spanX, height, thickness))
	boundaryWall(folder, Vector3.new((minX + maxX) / 2, centerY, maxZ), Vector3.new(spanX, height, thickness))
	folder.Parent = root
end

function EnvironmentService:InstantiateMap(mapName: string): (Instance, string)
	const mapsFolder = ServerStorage:FindFirstChild("Maps")
	const template = if mapsFolder then mapsFolder:FindFirstChild(mapName) else nil
	if not template then
		error(`mapa "{mapName}" nao encontrado em ServerStorage.Maps`)
	end

	const map = template:Clone()
	map.Name = "Map"
	self:BuildBoundary(map, mapName)
	return map, Maps[mapName].Lighting
end

function EnvironmentService:Instantiate(role: string, config: MatchConfig?): (Instance, string)
	if role == "Match" and config then
		return self:InstantiateMap(config.Map)
	end

	const lobbyFolder = ServerStorage:FindFirstChild("Lobby")
	const template = if lobbyFolder then lobbyFolder:FindFirstChild(MatchSettings.LobbyModel) else nil
	if not template then
		error(`lobby "{MatchSettings.LobbyModel}" nao encontrado em ServerStorage.Lobby`)
	end

	const lobby = template:Clone()
	lobby.Name = "Lobby"
	for _, child in lobby:GetChildren() do
		if child.Name == PLACEHOLDER_RIG then
			child:Destroy()
		end
	end
	return lobby, MatchSettings.LobbyLighting
end

function EnvironmentService:Mount(root: Instance, lightingName: string)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			descendant.Enabled = false
		end
	end
	if root:IsA("SpawnLocation") then
		root.Enabled = false
	end

	root.Parent = workspace
	self.Root = root

	self:ApplyLighting(lightingName)
end

function EnvironmentService:Load(role: string, config: MatchConfig?)
	const root, lightingName = self:Instantiate(role, config)
	self:Mount(root, lightingName)
end

function EnvironmentService:SwapMap(mapName: string): boolean
	if Maps[mapName] == nil then
		warn(`[EnvironmentService] mapa "{mapName}" nao existe em Maps`)
		return false
	end

	const built, root, lightingName = pcall(function(): (Instance, string)
		return self:InstantiateMap(mapName)
	end)
	if not built then
		warn(`[EnvironmentService] falha ao trocar para "{mapName}": {tostring(root)}`)
		return false
	end

	const previous = self.Root
	self:Mount(root :: Instance, lightingName :: string)
	if previous then
		previous:Destroy()
	end

	self.MapChanged:Fire(mapName)
	return true
end

EnvironmentService:OnInit(function(self)
	self:Setup()
end)

EnvironmentService:OnStart(function(self)
	const roleService = self.Dependencies.ServerRoleService
	roleService:OnReady(function()
		if not roleService:IsRouter() then
			self:Validate()

			const loaded, reason = pcall(function()
				self:Load(roleService:GetRole(), roleService:GetConfig())
			end)
			if not loaded then
				warn(`[EnvironmentService] falha ao carregar ambiente: {tostring(reason)}`)
			end
		end

		self.IsReady = true
		self.Ready:Fire()
	end)
end)

return EnvironmentService
