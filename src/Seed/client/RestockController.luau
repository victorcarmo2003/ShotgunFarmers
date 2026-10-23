--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local SeedSettings = require(ReplicatedStorage.shared.Seed.SeedSettings)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const FIREARM_SLOT = 1
const TICK_RATE = 4
const FILL_TRANSPARENCY = 0.65
const OUTLINE_TRANSPARENCY = 0

const RestockController = Modux.Controller("RestockController", {
	Require = { "GameStateController", "WeaponController" },
	Priority = 300,
})

function RestockController:Setup()
	const highlight = Instance.new("Highlight")
	highlight.Name = "RestockHighlight"
	highlight.FillColor = SeedSettings.RESTOCK_HIGHLIGHT_FILL
	highlight.OutlineColor = SeedSettings.RESTOCK_HIGHLIGHT_OUTLINE
	highlight.FillTransparency = FILL_TRANSPARENCY
	highlight.OutlineTransparency = OUTLINE_TRANSPARENCY
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

	self.Highlight = highlight :: Highlight
	self.Target = nil :: Instance?
end

function RestockController:NeedsWeapon(): boolean
	const weapons = self.Dependencies.WeaponController
	return (weapons.Slots()[FIREARM_SLOT] or 0) == 0 or (weapons.Ammo()[FIREARM_SLOT] or 0) == 0
end

local function rootPosition(): Vector3?
	const character = Players.LocalPlayer.Character
	if not character then
		return nil
	end

	const humanoid = character:FindFirstChildOfClass("Humanoid")
	const root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

local function cratePosition(crate: Instance): Vector3?
	if crate:IsA("Model") then
		return crate:GetPivot().Position
	end
	if crate:IsA("BasePart") then
		return crate.Position
	end
	return nil
end

function RestockController:Nearest(origin: Vector3): Instance?
	local best: Instance? = nil
	local bestDistance = math.huge
	local bestStocked = false

	for _, crate in CollectionService:GetTagged(SeedSettings.RESTOCK_TAG) do
		if crate:GetAttribute(SeedSettings.RESTOCK_ACTIVE_ATTRIBUTE) ~= true or not crate:IsDescendantOf(workspace) then
			continue
		end

		const position = cratePosition(crate)
		if not position then
			continue
		end

		const stocked = crate:GetAttribute(SeedSettings.RESTOCK_STOCKED_ATTRIBUTE) == true
		const distance = (position - origin).Magnitude
		if (stocked and not bestStocked) or (stocked == bestStocked and distance < bestDistance) then
			best = crate
			bestDistance = distance
			bestStocked = stocked
		end
	end

	return best
end

function RestockController:SetTarget(crate: Instance?)
	if crate == self.Target then
		return
	end
	self.Target = crate

	self.Highlight.Adornee = crate
	self.Highlight.Parent = crate
end

function RestockController:Step()
	const origin = rootPosition()
	if not origin or not self.Dependencies.GameStateController:Can("Combat") or not self:NeedsWeapon() then
		self:SetTarget(nil)
		return
	end

	self:SetTarget(self:Nearest(origin))
end

RestockController:OnInit(function(self)
	self:Setup()
end)

RestockController:OnTick(function(self)
	self:Step()
end, TICK_RATE)

return RestockController
