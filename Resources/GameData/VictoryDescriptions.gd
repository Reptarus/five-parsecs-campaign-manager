class_name VictoryDescriptions
extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

const DESCRIPTIONS = {
	GlobalEnums.CampaignVictoryType.WEALTH_GOAL: "Accumulate 5000 credits through jobs, trade, and salvage.",
	GlobalEnums.CampaignVictoryType.REPUTATION_GOAL: "Become a notorious crew through successful missions and story events.",
	GlobalEnums.CampaignVictoryType.STORY_COMPLETE: "Complete the 7-stage narrative campaign.",
	GlobalEnums.CampaignVictoryType.SURVIVAL: "Successfully complete challenging missions and survive.",
	GlobalEnums.CampaignVictoryType.FACTION_DOMINANCE: "Become dominant in a faction"
}

static func get_description(victory_type: int) -> String:
	return DESCRIPTIONS.get(victory_type, "Unknown victory condition") 