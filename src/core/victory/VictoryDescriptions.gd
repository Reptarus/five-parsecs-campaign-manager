extends Resource

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

var _VICTORY_DESCRIPTIONS: Dictionary = {
	GlobalEnums.FiveParcsecsCampaignVictoryType.QUESTS_5: "Complete 5 questline missions",
	GlobalEnums.FiveParcsecsCampaignVictoryType.QUESTS_10: "Complete 10 questline missions",
	GlobalEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE: "Complete the main story",
	GlobalEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL: "Accumulate specified wealth",
	GlobalEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL: "Achieve specified reputation",
	GlobalEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE: "Become the dominant faction"
}

var _MISSION_DESCRIPTIONS: Dictionary = {
	GlobalEnums.MissionVictoryType.ELIMINATION: "Eliminate all enemy forces",
	GlobalEnums.MissionVictoryType.EXTRACTION: "Reach extraction point",
	# Add other mission victory descriptions
}

func get_description(victory_type: int) -> String:
	match victory_type:
		GlobalEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE:
			return "Complete the main story campaign"
		GlobalEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL:
			return "Accumulate significant wealth"
		GlobalEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL:
			return "Build your reputation in the galaxy"
		GlobalEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE:
			return "Achieve dominance with your chosen faction"
		GlobalEnums.FiveParcsecsCampaignVictoryType.CREDITS_THRESHOLD:
			return "Reach the credit threshold"
		_:
			return _VICTORY_DESCRIPTIONS.get(victory_type, "Unknown victory condition")

static func get_mission_description(victory_type: int) -> String:
	match victory_type:
		GlobalEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE:
			return "Story mission objective"
		GlobalEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL:
			return "Wealth accumulation objective"
		GlobalEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL:
			return "Reputation building objective"
		GlobalEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE:
			return "Faction influence objective"
		_:
			return "Standard mission objective"