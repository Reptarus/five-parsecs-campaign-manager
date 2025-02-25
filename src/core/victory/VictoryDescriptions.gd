extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var CAMPAIGN_DESCRIPTIONS: Dictionary = {
	GameEnums.FiveParcsecsCampaignVictoryType.TURNS_20: "Play 20 campaign turns",
	GameEnums.FiveParcsecsCampaignVictoryType.TURNS_50: "Play 50 campaign turns",
	GameEnums.FiveParcsecsCampaignVictoryType.TURNS_100: "Play 100 campaign turns",
	GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_3: "Complete 3 story quests",
	GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_5: "Complete 5 story quests",
	GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_10: "Complete 10 story quests",
	GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE: "Complete the main story",
	GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL: "Accumulate specified wealth",
	GameEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL: "Achieve specified reputation",
	GameEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE: "Become the dominant faction"
}

var MISSION_DESCRIPTIONS: Dictionary = {
	GameEnums.MissionVictoryType.ELIMINATION: "Eliminate all enemy forces",
	GameEnums.MissionVictoryType.EXTRACTION: "Reach extraction point",
	# Add other mission victory descriptions
}

static func get_campaign_description(victory_type: int) -> String:
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
			return "Reach a specific credit threshold"
		GameEnums.FiveParcsecsCampaignVictoryType.REPUTATION_THRESHOLD:
			return "Achieve a specific reputation level"
		GameEnums.FiveParcsecsCampaignVictoryType.MISSION_COUNT:
			return "Complete a set number of missions"
		_:
			return "Unknown victory condition"

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