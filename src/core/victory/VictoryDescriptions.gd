extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var _VICTORY_DESCRIPTIONS: Dictionary = {
	GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_5: "Complete 5 questline missions",
	GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_10: "Complete 10 questline missions",
	GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE: "Complete the main story",
	GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL: "Accumulate specified wealth",
	GameEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL: "Achieve specified reputation",
	GameEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE: "Become the dominant faction"
}

var _MISSION_DESCRIPTIONS: Dictionary = {
	GameEnums.MissionVictoryType.ELIMINATION: "Eliminate all enemy forces",
	GameEnums.MissionVictoryType.EXTRACTION: "Reach extraction point",
	# Add other mission victory descriptions
}

func get_description(victory_type: int) -> String:
	match victory_type:
		GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE:
			return "Complete the main story campaign"
		GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL:
			return "Accumulate significant wealth"
		GameEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL:
			return "Build your reputation in the galaxy"
		GameEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE:
			return "Achieve dominance with your chosen faction"
		GameEnums.FiveParcsecsCampaignVictoryType.CREDITS_THRESHOLD:
			return "Reach the credit threshold"
		_:
			return _VICTORY_DESCRIPTIONS.get(victory_type, "Unknown victory condition")

static func get_mission_description(victory_type: int) -> String:
	match victory_type:
		GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE:
			return "Story mission objective"
		GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL:
			return "Wealth accumulation objective"
		GameEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL:
			return "Reputation building objective"
		GameEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE:
			return "Faction influence objective"
		_:
			return "Standard mission objective"