--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const CharacterService = Modux.Service("CharacterService", { Require = { "PlayerService" }, Priority = 760 })

function CharacterService:StripDefaultAnimate(character: Model)
	const animate = character:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
end

function CharacterService:DisableAccessoryQuery(character: Model)
	for _, descendant in character:GetDescendants() do
		if not descendant:IsA("Accessory") then
			continue
		end
		for _, part in descendant:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanQuery = false
			end
		end
	end
end

function CharacterService:Sanitize(character: Model)
	self:StripDefaultAnimate(character)
	self:DisableAccessoryQuery(character)

	const connection = character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") and descendant:FindFirstAncestorWhichIsA("Accessory") then
			descendant.CanQuery = false
		end
	end)

	character.Destroying:Once(function()
		connection:Disconnect()
	end)
end

CharacterService:OnInit(function(self)
	self.Dependencies.PlayerService.CharacterAdded:Connect(function(_player, character)
		self:Sanitize(character)
	end)
end)

return CharacterService
