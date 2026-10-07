--!strict
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local PlayerAnimations = require(ReplicatedStorage.shared.Character.PlayerAnimations)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const ASSET_PREFIX = "rbxassetid://"
const PRIORITY_FOLDERS = { "Weapons" }
const LATER_FOLDERS = { "VFX", "Sounds", "Seeds" }

const PreloadController = Modux.Controller("PreloadController", {
	Priority = 990,
})

function PreloadController:Setup()
	self.Done = false :: boolean
	self.Animations = {} :: { Animation }
end

local function collectAnimationIds(node: any, into: { [string]: boolean })
	if type(node) == "string" then
		if string.sub(node, 1, #ASSET_PREFIX) == ASSET_PREFIX then
			into[node] = true
		end
		return
	end

	if type(node) == "table" then
		for _, child in node do
			collectAnimationIds(child, into)
		end
	end
end

local function assetFolders(names: { string }): { Instance }
	const list: { Instance } = {}
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return list
	end

	for _, name in names do
		const folder = assets:FindFirstChild(name)
		if folder then
			table.insert(list, folder)
		end
	end
	return list
end

function PreloadController:AnimationInstances(): { Animation }
	const ids: { [string]: boolean } = {}
	collectAnimationIds(PlayerAnimations, ids)

	for id in ids do
		const animation = Instance.new("Animation")
		animation.AnimationId = id
		table.insert(self.Animations, animation)
	end

	return self.Animations
end

local function gunImages(): { string }
	const images: { string } = {}
	for _, gunData in GetGun.All do
		if gunData.ImageID ~= "" then
			table.insert(images, gunData.ImageID)
		end
	end
	return images
end

local function preload(list: { any })
	if #list == 0 then
		return
	end

	const ok, err = pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
	if not ok then
		warn(`[PreloadController] falha no preload: {err}`)
	end
end

function PreloadController:Run()
	const started = os.clock()

	const first: { any } = {}
	for _, animation in self:AnimationInstances() do
		table.insert(first, animation)
	end
	for _, folder in assetFolders(PRIORITY_FOLDERS) do
		table.insert(first, folder)
	end
	preload(first)

	const later: { any } = assetFolders(LATER_FOLDERS)
	for _, image in gunImages() do
		table.insert(later, image)
	end
	preload(later)

	self.Done = true
	print(`[PreloadController] {#self.Animations} animacoes e assets de armas carregados em {math.round((os.clock() - started) * 1000)} ms`)
end

PreloadController:OnInit(function(self)
	self:Setup()
end)

PreloadController:OnStart(function(self)
	task.spawn(function()
		self:Run()
	end)
end)

return PreloadController
