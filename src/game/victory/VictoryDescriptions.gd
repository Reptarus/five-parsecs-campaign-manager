# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Resource

const Self = preload("res://src/game/victory/VictoryDescriptions.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

enum VictoryCategory {
	DURATION,
	COMBAT,
	STORY,
	WEALTH,
	CHALLENGE
}

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
			return [GameEnums.FiveParcsecsCampaignVictoryType.TURNS_20, GameEnums.FiveParcsecsCampaignVictoryType.TURNS_50, GameEnums.FiveParcsecsCampaignVictoryType.TURNS_100]
		VictoryCategory.COMBAT:
			return [GameEnums.FiveParcsecsCampaignVictoryType.BATTLES_20, GameEnums.FiveParcsecsCampaignVictoryType.BATTLES_50, GameEnums.FiveParcsecsCampaignVictoryType.BATTLES_100]
		VictoryCategory.STORY:
			return [GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_3, GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_5, GameEnums.FiveParcsecsCampaignVictoryType.QUESTS_10, GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE]
		VictoryCategory.WEALTH:
			return [GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL, GameEnums.FiveParcsecsCampaignVictoryType.CREDITS_THRESHOLD]
		VictoryCategory.CHALLENGE:
			return [GameEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL, GameEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE, GameEnums.FiveParcsecsCampaignVictoryType.MISSION_COUNT]
	return []

static func get_victory_name(victory_type: int) -> String:
	## Return display name for a victory type
	return get_campaign_description(victory_type)

static func get_value_range(victory_type: int) -> Dictionary:
	## Return value range (min, max, default) for configurable victory types
	match victory_type:
		GameEnums.FiveParcsecsCampaignVictoryType.TURNS_20: return {"min": 10, "max": 30, "default": 20}
		GameEnums.FiveParcsecsCampaignVictoryType.TURNS_50: return {"min": 30, "max": 75, "default": 50}
		GameEnums.FiveParcsecsCampaignVictoryType.TURNS_100: return {"min": 75, "max": 150, "default": 100}
		GameEnums.FiveParcsecsCampaignVictoryType.CREDITS_THRESHOLD: return {"min": 10000, "max": 200000, "default": 50000}
		GameEnums.FiveParcsecsCampaignVictoryType.REPUTATION_THRESHOLD: return {"min": 5, "max": 30, "default": 10}
	return {"min": 1, "max": 100, "default": 10}

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