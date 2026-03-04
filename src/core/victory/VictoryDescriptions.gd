extends Resource
var CAMPAIGN_DESCRIPTIONS: Dictionary = {
	GlobalEnums.FiveParcsecsCampaignVictoryType.TURNS_20: "Play 20 campaign turns",
	GlobalEnums.FiveParcsecsCampaignVictoryType.TURNS_50: "Play 50 campaign turns",
	GlobalEnums.FiveParcsecsCampaignVictoryType.TURNS_100: "Play 100 campaign turns",
	GlobalEnums.FiveParcsecsCampaignVictoryType.QUESTS_3: "Complete 3 story quests",
	GlobalEnums.FiveParcsecsCampaignVictoryType.QUESTS_5: "Complete 5 story quests",
	GlobalEnums.FiveParcsecsCampaignVictoryType.QUESTS_10: "Complete 10 story quests",
	GlobalEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE: "Complete the main story",
	GlobalEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL: "Accumulate specified wealth",
	GlobalEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL: "Achieve specified reputation",
	GlobalEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE: "Become the dominant faction"
}

var MISSION_DESCRIPTIONS: Dictionary = {
	GlobalEnums.MissionVictoryType.ELIMINATION: "Eliminate all enemy forces",
	GlobalEnums.MissionVictoryType.EXTRACTION: "Reach extraction point",
	# Add other mission victory descriptions
}

static func get_campaign_description(victory_type: int) -> String:
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
			return "Reach a specific credit threshold"
		GlobalEnums.FiveParcsecsCampaignVictoryType.REPUTATION_THRESHOLD:
			return "Achieve a specific reputation level"
		GlobalEnums.FiveParcsecsCampaignVictoryType.MISSION_COUNT:
			return "Complete a set number of missions"
		_:
			return "Unknown victory condition"

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