class_name FPCM_VictoryDescriptions
extends Resource

# GlobalEnums available as autoload singleton

var _CAMPAIGN_DESCRIPTIONS: Dictionary = {
	GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20: "Play 20 campaign turns",
	GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50: "Play 50 campaign turns",
	GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100: "Play 100 campaign turns",
	GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3: "Complete 3 story quests",
	GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5: "Complete 5 story quests",
	GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10: "Complete 10 story quests",
	GlobalEnums.FiveParsecsCampaignVictoryType.STORY_COMPLETE: "Complete the main story",
	GlobalEnums.FiveParsecsCampaignVictoryType.WEALTH_GOAL: "Accumulate specified wealth",
	GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_GOAL: "Achieve specified reputation",
	GlobalEnums.FiveParsecsCampaignVictoryType.FACTION_DOMINANCE: "Become the dominant faction"
}

var _MISSION_DESCRIPTIONS: Dictionary = {
	GlobalEnums.MissionVictoryType.ELIMINATION: "Eliminate all enemy forces",
	GlobalEnums.MissionVictoryType.EXTRACTION: "Reach extraction point"
	# Add other mission victory descriptions
}

static func get_campaign_description(victory_type: int) -> String:
	match victory_type:
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_COMPLETE:
			return "Complete the main story campaign"
		GlobalEnums.FiveParsecsCampaignVictoryType.WEALTH_GOAL:
			return "Accumulate significant wealth"
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_GOAL:
			return "Build your reputation in the galaxy"
		GlobalEnums.FiveParsecsCampaignVictoryType.FACTION_DOMINANCE:
			return "Achieve dominance with your chosen faction"
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_THRESHOLD:
			return "Reach a specific credit threshold"
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_THRESHOLD:
			return "Achieve a specific reputation level"
		GlobalEnums.FiveParsecsCampaignVictoryType.MISSION_COUNT:
			return "Complete a set number of missions"
		_:
			return "Unknown victory condition"

static func get_mission_description(victory_type: int) -> String:
	match victory_type:
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_COMPLETE:
			return "Story mission objective"
		GlobalEnums.FiveParsecsCampaignVictoryType.WEALTH_GOAL:
			return "Wealth accumulation objective"
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_GOAL:
			return "Reputation building objective"
		GlobalEnums.FiveParsecsCampaignVictoryType.FACTION_DOMINANCE:
			return "Faction influence objective"
		_:
			return "Standard mission objective"