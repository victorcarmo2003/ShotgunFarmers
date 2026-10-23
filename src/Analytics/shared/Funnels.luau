--!strict
export type FunnelName =
	"Matchmaking"
	| "PlantLoop"
	| "Rounds"
	| "Revive"
	| "RobuxShop"
	| "Skins"
	| "Party"
	| "PrivateRoom"
	| "Practice"

const Funnels = {
	Debug = true,
	MaxFields = 3,
	FieldLength = 50,
	TeleportKey = "Funnel",
	ClientCooldown = 0.25,
	ClientSteps = {
		Revive = { "SawOffer", "PressedRevive", "PromptOpened" },
		RobuxShop = { "OpenedShop", "ClickedItem", "PromptOpened" },
		Skins = { "OpenedCosmetics", "InspectedWeapon", "TriedBuy" },
		Party = { "OpenedFriends" },
	} :: { [FunnelName]: { string } },
	Steps = {
		Matchmaking = { "Play", "SearchBegin", "TargetFound", "TeleportFired", "Admitted", "SpawnedInCombat" },
		PlantLoop = {
			"SpawnedWithWeapon",
			"FirstSeedPlanted",
			"SeedHarvestable",
			"Harvested",
			"HarvestedNewWeapon",
			"KillWithHarvested",
			"ThreeHarvestedKills",
		},
		Rounds = { "JoinedMatch", "FinishedRound", "SawSummary", "VotedMap", "Round2", "Round3", "Round5" },
		Revive = { "Died", "SawOffer", "PressedRevive", "PromptOpened", "Purchased", "Revived", "KillAfterRevive" },
		RobuxShop = { "OpenedShop", "ClickedItem", "PromptOpened", "Purchased", "ItemUsed" },
		Skins = { "OpenedCosmetics", "InspectedWeapon", "TriedBuy", "Bought", "Equipped", "PlayedWithSkin" },
		Party = { "OpenedFriends", "Invited", "InviteAccepted", "JoinedLeaderLobby", "PlayedTogether", "TogetherRound3" },
		PrivateRoom = { "CreatedOrJoined", "CodeValid", "OtherJoined", "MatchStarted", "TwoHumans" },
		Practice = { "EnteredPractice", "EquippedWeapon", "LeftPractice", "PlayedRealMatch" },
	} :: { [FunnelName]: { string } },
}

return Funnels
