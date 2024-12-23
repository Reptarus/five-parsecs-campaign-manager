class_name VictoryDescriptions
extends Resource

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

var CAMPAIGN_DESCRIPTIONS: Dictionary = {
	GlobalEnums.CampaignVictoryType.TURNS_20: "Play 20 campaign turns",
	GlobalEnums.CampaignVictoryType.TURNS_50: "Play 50 campaign turns", 
	GlobalEnums.CampaignVictoryType.TURNS_100: "Play 100 campaign turns",
	GlobalEnums.CampaignVictoryType.QUESTS_3: "Complete 3 story quests",
	GlobalEnums.CampaignVictoryType.QUESTS_5: "Complete 5 story quests",
	GlobalEnums.CampaignVictoryType.QUESTS_10: "Complete 10 story quests",
	GlobalEnums.CampaignVictoryType.STORY_COMPLETE: "Complete the main story",
	GlobalEnums.CampaignVictoryType.WEALTH_GOAL: "Accumulate specified wealth",
	GlobalEnums.CampaignVictoryType.REPUTATION_GOAL: "Achieve specified reputation",
	GlobalEnums.CampaignVictoryType.FACTION_DOMINANCE: "Become the dominant faction"
}

var MISSION_DESCRIPTIONS: Dictionary = {
	GlobalEnums.MissionVictoryType.ELIMINATION: "Eliminate all enemy forces",
	GlobalEnums.MissionVictoryType.EXTRACTION: "Reach extraction point",
	# Add other mission victory descriptions
}

static func get_campaign_description(victory_type: int) -> String:
	var descriptions = VictoryDescriptions.new()
	return descriptions.CAMPAIGN_DESCRIPTIONS.get(victory_type, "Unknown victory condition")

static func get_mission_description(victory_type: int) -> String:
	var descriptions = VictoryDescriptions.new()
	return descriptions.MISSION_DESCRIPTIONS.get(victory_type, "Unknown victory condition")