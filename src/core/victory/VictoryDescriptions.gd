class_name VictoryDescriptions
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var CAMPAIGN_DESCRIPTIONS: Dictionary = {
	GameEnums.CampaignVictoryType.TURNS_20: "Play 20 campaign turns",
	GameEnums.CampaignVictoryType.TURNS_50: "Play 50 campaign turns",
	GameEnums.CampaignVictoryType.TURNS_100: "Play 100 campaign turns",
	GameEnums.CampaignVictoryType.QUESTS_3: "Complete 3 story quests",
	GameEnums.CampaignVictoryType.QUESTS_5: "Complete 5 story quests",
	GameEnums.CampaignVictoryType.QUESTS_10: "Complete 10 story quests",
	GameEnums.CampaignVictoryType.STORY_COMPLETE: "Complete the main story",
	GameEnums.CampaignVictoryType.WEALTH_GOAL: "Accumulate specified wealth",
	GameEnums.CampaignVictoryType.REPUTATION_GOAL: "Achieve specified reputation",
	GameEnums.CampaignVictoryType.FACTION_DOMINANCE: "Become the dominant faction"
}

var MISSION_DESCRIPTIONS: Dictionary = {
	GameEnums.MissionVictoryType.ELIMINATION: "Eliminate all enemy forces",
	GameEnums.MissionVictoryType.EXTRACTION: "Reach extraction point",
	# Add other mission victory descriptions
}

static func get_campaign_description(victory_type: int) -> String:
	var descriptions = VictoryDescriptions.new()
	return descriptions.CAMPAIGN_DESCRIPTIONS.get(victory_type, "Unknown victory condition")

static func get_mission_description(victory_type: int) -> String:
	var descriptions = VictoryDescriptions.new()
	return descriptions.MISSION_DESCRIPTIONS.get(victory_type, "Unknown victory condition")