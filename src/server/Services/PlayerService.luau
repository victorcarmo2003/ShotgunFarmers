local Modux = require(game.ReplicatedStorage.Shared.Modux)
local PlayerService = Modux.Service("PlayerService")
type Self = typeof(PlayerService)

PlayerService._playerAddedCallbacks = {}
PlayerService._playerRemovedCallbacks = {}
PlayerService._characterAddedCallbacks = {}
PlayerService._characterRemovedCallbacks = {}
PlayerService.allPlayers = {} :: { [number]: Player }
PlayerService.allCharacters = {} :: { [number]: R6 }

PlayerService.OnPlayerAdded = function(self: Self, callback: (Player: Player) -> ())
	table.insert(PlayerService._playerAddedCallbacks, callback)
end

PlayerService.OnPlayerRemoved = function(self: Self, callback: (Player: Player) -> ())
	table.insert(PlayerService._playerRemovedCallbacks, callback)
end

PlayerService.OnCharacterAdded = function(self: Self, callback: (Character: R6, Player: Player) -> ())
	table.insert(PlayerService._characterAddedCallbacks, callback)
end

PlayerService.OnCharacterRemoved = function(self: Self, callback: (Character: R6, Player: Player) -> ())
	table.insert(PlayerService._characterRemovedCallbacks, callback)
end

PlayerService.GetAllPlayers = function(self: Self): { Player }
	return table.clone(self.allPlayers)
end

PlayerService.GetAllCharacters = function(self: Self): { R6 }
	return table.clone(self.allCharacters)
end

local function triggerCharacterAdded(character: R6, player: Player)
	for _, cb in PlayerService._characterAddedCallbacks do
		task.spawn(cb, character, player)
	end
end

local function triggerCharacterRemoved(character: R6, player: Player)
	for _, cb in PlayerService._characterRemovedCallbacks do
		task.spawn(cb, character, player)
	end
end

local function triggerPlayerAdded(player: Player)
	for _, cb in PlayerService._playerAddedCallbacks do
		task.spawn(cb, player)
	end

	table.insert(PlayerService.allPlayers, player)

	PlayerService:Cleanup(player.CharacterAdded:Connect(function(character)
		table.insert(PlayerService.allCharacters, character)
		triggerCharacterAdded(character, player)
	end))

	if player.Character then
		table.insert(PlayerService.allCharacters, player.Character)
		triggerCharacterAdded(player.Character :: R6, player)
	end

	PlayerService:Cleanup(player.CharacterRemoving:Connect(function(character)
		print(
			`[PlayerService] CharacterRemoving disparado -- {player.Name} ({#PlayerService._characterRemovedCallbacks} callback(s))`
		)
		triggerCharacterRemoved(character, player)
		local position = table.find(PlayerService.allCharacters, character)
		if position then
			table.remove(PlayerService.allCharacters, position)
		end
	end))
end

local function triggerPlayerRemoved(player: Player)
	for _, cb in PlayerService._playerRemovedCallbacks do
		task.spawn(cb, player)
	end
	local position = table.find(PlayerService.allPlayers, player)
	if position then
		table.remove(PlayerService.allPlayers, position)
	end
end

PlayerService:OnInit(function(self)
	local Players = game:GetService("Players")

	self:Cleanup(Players.PlayerAdded:Connect(triggerPlayerAdded))
	self:Cleanup(Players.PlayerRemoving:Connect(triggerPlayerRemoved))

	for _, player in Players:GetPlayers() do
		task.spawn(triggerPlayerAdded, player)
	end
end)

PlayerService:OnDestroy(function(self)
	table.clear(self._playerAddedCallbacks)
	table.clear(self._playerRemovedCallbacks)
	table.clear(self._characterAddedCallbacks)
	table.clear(self._characterRemovedCallbacks)
end)

export type R6 = {
	Head: {
		Mesh: SpecialMesh,
		face: Decal,
		HairAttachment: Attachment,
		HatAttachment: Attachment,
		FaceFrontAttachment: Attachment,
		FaceCenterAttachment: Attachment,
	} & Part,
	Torso: {
		roblox: Decal,
		NeckAttachment: Attachment,
		BodyFrontAttachment: Attachment,
		BodyBackAttachment: Attachment,
		LeftCollarAttachment: Attachment,
		RightCollarAttachment: Attachment,
		WaistFrontAttachment: Attachment,
		WaistCenterAttachment: Attachment,
		WaistBackAttachment: Attachment,
		Right_Shoulder: Motor6D,
		Left_Shoulder: Motor6D,
		Right_Hip: Motor6D,
		Left_Hip: Motor6D,
		Neck: Motor6D,
	} & Part,
	Left_Arm: {
		LeftShoulderAttachment: Attachment,
		LeftGripAttachment: Attachment,
	} & Part,
	Right_Arm: {
		RightShoulderAttachment: Attachment,
		RightGripAttachment: Attachment,
	} & Part,
	Left_Leg: {
		LeftFootAttachment: Attachment,
	} & Part,
	Right_Leg: {
		RightFootAttachment: Attachment,
	} & Part,
	Humanoid: {
		Status: Status,
		Animator: Animator,
		HumanoidDescription: {
			BodyPartDescription_1: BodyPartDescription,
			BodyPartDescription_2: BodyPartDescription,
			BodyPartDescription_3: BodyPartDescription,
			BodyPartDescription_4: BodyPartDescription,
			BodyPartDescription_5: BodyPartDescription,
			BodyPartDescription_6: BodyPartDescription,
		} & HumanoidDescription,
	} & Humanoid,
	HumanoidRootPart: {
		RootAttachment: Attachment,
		RootJoint: Motor6D,
	} & Part,
	Animate: {
		idle: {
			Animation1: {
				Weight: NumberValue,
			} & Animation,
			Animation2: {
				Weight: NumberValue,
			} & Animation,
		} & StringValue,
		walk: {
			WalkAnim: Animation,
		} & StringValue,
		run: {
			RunAnim: Animation,
		} & StringValue,
		jump: {
			JumpAnim: Animation,
		} & StringValue,
		climb: {
			ClimbAnim: Animation,
		} & StringValue,
		toolnone: {
			ToolNoneAnim: Animation,
		} & StringValue,
		fall: {
			FallAnim: Animation,
		} & StringValue,
		sit: {
			SitAnim: Animation,
		} & StringValue,
		PlayEmote: BindableFunction,
		ScaleDampeningPercent: NumberValue,
	} & LocalScript,
	Body_Colors: BodyColors,
} & Model

return PlayerService
