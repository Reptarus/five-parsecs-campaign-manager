# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Resource
enum VictoryCategory {
	DURATION,
	COMBAT,
	STORY,
	WEALTH,
	CHALLENGE
}

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

static func get_victory_data(victory_type: int) -> Dictionary:
	## Get victory condition data for UI display
	return {
		"name": get_campaign_description(victory_type),
		"short_desc": get_campaign_description(victory_type),
		"type": victory_type
	}

static func get_victory_types_by_category(category: int) -> Array:
	## Return victory types for a given VictoryCategory
	match category:
		VictoryCategory.DURATION:
			return [GlobalEnums.FiveParcsecsCampaignVictoryType.TURNS_20, GlobalEnums.FiveParcsecsCampaignVictoryType.TURNS_50, GlobalEnums.FiveParcsecsCampaignVictoryType.TURNS_100]
		VictoryCategory.COMBAT:
			return [GlobalEnums.FiveParcsecsCampaignVictoryType.BATTLES_20, GlobalEnums.FiveParcsecsCampaignVictoryType.BATTLES_50, GlobalEnums.FiveParcsecsCampaignVictoryType.BATTLES_100]
		VictoryCategory.STORY:
			return [GlobalEnums.FiveParcsecsCampaignVictoryType.QUESTS_3, GlobalEnums.FiveParcsecsCampaignVictoryType.QUESTS_5, GlobalEnums.FiveParcsecsCampaignVictoryType.QUESTS_10, GlobalEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE]
		VictoryCategory.WEALTH:
			return [GlobalEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL, GlobalEnums.FiveParcsecsCampaignVictoryType.CREDITS_THRESHOLD]
		VictoryCategory.CHALLENGE:
			return [GlobalEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL, GlobalEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE, GlobalEnums.FiveParcsecsCampaignVictoryType.MISSION_COUNT]
	return []

static func get_victory_name(victory_type: int) -> String:
	## Return display name for a victory type
	return get_campaign_description(victory_type)

static func get_value_range(victory_type: int) -> Dictionary:
	## Return value range (min, max, default) for configurable victory types
	match victory_type:
		GlobalEnums.FiveParcsecsCampaignVictoryType.TURNS_20: return {"min": 10, "max": 30, "default": 20}
		GlobalEnums.FiveParcsecsCampaignVictoryType.TURNS_50: return {"min": 30, "max": 75, "default": 50}
		GlobalEnums.FiveParcsecsCampaignVictoryType.TURNS_100: return {"min": 75, "max": 150, "default": 100}
		GlobalEnums.FiveParcsecsCampaignVictoryType.CREDITS_THRESHOLD: return {"min": 10000, "max": 200000, "default": 50000}
		GlobalEnums.FiveParcsecsCampaignVictoryType.REPUTATION_THRESHOLD: return {"min": 5, "max": 30, "default": 10}
	return {"min": 1, "max": 100, "default": 10}

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