class_name VictoryDescriptions
extends Resource

const GlobalEnums := preload("res://Resources/GameData/GlobalEnums.gd")

const DESCRIPTIONS = {
	GlobalEnums.CampaignVictoryType.WEALTH_5000: "Accumulate 5000 credits through jobs, trade, and salvage.",
	GlobalEnums.CampaignVictoryType.REPUTATION_NOTORIOUS: "Become a notorious crew through successful missions and story events.",
	GlobalEnums.CampaignVictoryType.STORY_COMPLETE: "Complete the 7-stage narrative campaign.",
	GlobalEnums.CampaignVictoryType.BLACK_ZONE_MASTER: "Successfully complete 3 super-hard Black Zone jobs.",
	GlobalEnums.CampaignVictoryType.RED_ZONE_VETERAN: "Successfully complete 5 high-risk Red Zone jobs.",
	GlobalEnums.CampaignVictoryType.QUEST_MASTER: "Complete 10 quests",
	GlobalEnums.CampaignVictoryType.FACTION_DOMINANCE: "Become dominant in a faction",
	GlobalEnums.CampaignVictoryType.FLEET_COMMANDER: "Build up a significant fleet"
}

static func get_description(victory_type: int) -> String:
	return DESCRIPTIONS.get(victory_type, "Unknown victory condition") 