class_name CampaignVictoryConstants
## Campaign Victory Constants for Five Parsecs Campaign Manager
## Transferred from test helpers to production code
## Based on Five Parsecs Core Rulebook victory conditions and campaign goals
##
## Usage: Reference these constants in campaign state validation and victory checking
## Architecture: Pure constants class - no state, no dependencies

## Victory condition types
enum VictoryConditionType {
	SURVIVE_TURNS,     # Complete target number of campaign turns
	STORY_POINTS,      # Accumulate target story points
	WEALTH,            # Accumulate target credits
	REPUTATION,        # Achieve target reputation level
	CREW_SIZE,         # Build crew to target size
	DEFEAT_RIVAL,      # Defeat primary rival
	CUSTOM             # Custom victory condition
}

## Primary victory conditions (one must be met to win campaign)
const PRIMARY_VICTORY_CONDITIONS: Dictionary = {
	VictoryConditionType.SURVIVE_TURNS: {
		"name": "Survival Campaign",
		"description": "Survive %d campaign turns",
		"default_target": 10,
		"min_target": 5,
		"max_target": 50
	},
	VictoryConditionType.STORY_POINTS: {
		"name": "Story Campaign",
		"description": "Accumulate %d story points",
		"default_target": 20,
		"min_target": 10,
		"max_target": 100
	},
	VictoryConditionType.WEALTH: {
		"name": "Wealth Campaign",
		"description": "Accumulate %d credits",
		"default_target": 500,
		"min_target": 250,
		"max_target": 2000
	},
	VictoryConditionType.REPUTATION: {
		"name": "Reputation Campaign",
		"description": "Achieve reputation level %d",
		"default_target": 10,
		"min_target": 5,
		"max_target": 20
	},
	VictoryConditionType.CREW_SIZE: {
		"name": "Crew Building Campaign",
		"description": "Build crew to %d members",
		"default_target": 8,
		"min_target": 5,
		"max_target": 12
	},
	VictoryConditionType.DEFEAT_RIVAL: {
		"name": "Nemesis Campaign",
		"description": "Defeat primary rival in battle",
		"requires_special_mission": true
	}
}

## Achievement thresholds (optional campaign goals)
const ACHIEVEMENT_THRESHOLDS: Dictionary = {
	"wealthy_captain": {
		"name": "Wealthy Captain",
		"description": "Accumulated 100+ credits",
		"threshold": 100,
		"check_type": "credits"
	},
	"famous_crew": {
		"name": "Famous Crew",
		"description": "Built crew of 5+ members",
		"threshold": 5,
		"check_type": "crew_size"
	},
	"veteran_captain": {
		"name": "Veteran Captain",
		"description": "Earned 50+ XP",
		"threshold": 50,
		"check_type": "captain_xp"
	},
	"iron_will": {
		"name": "Iron Will",
		"description": "No crew deaths throughout campaign",
		"threshold": 0,  # Zero casualties
		"check_type": "casualties"
	},
	"arsenal": {
		"name": "Well-Armed",
		"description": "Accumulated 10+ weapons",
		"threshold": 10,
		"check_type": "weapon_count"
	},
	"survivor": {
		"name": "Survivor",
		"description": "Survived 20+ campaign turns",
		"threshold": 20,
		"check_type": "turns"
	},
	"wealthy": {
		"name": "Filthy Rich",
		"description": "Accumulated 500+ credits",
		"threshold": 500,
		"check_type": "credits"
	},
	"experienced": {
		"name": "Combat Veteran",
		"description": "Captain earned 100+ XP",
		"threshold": 100,
		"check_type": "captain_xp"
	}
}

## Common campaign target turn counts
const COMMON_TARGET_TURNS: Array[int] = [5, 10, 15, 20, 30, 50]

## Campaign difficulty multipliers for victory conditions
const DIFFICULTY_MULTIPLIERS: Dictionary = {
	"EASY": {
		"turns": 0.75,    # 25% fewer turns
		"credits": 0.75,  # 25% less credits
		"story_points": 0.75
	},
	"NORMAL": {
		"turns": 1.0,
		"credits": 1.0,
		"story_points": 1.0
	},
	"HARD": {
		"turns": 1.25,    # 25% more turns
		"credits": 1.5,   # 50% more credits
		"story_points": 1.5
	},
	"BRUTAL": {
		"turns": 1.5,     # 50% more turns
		"credits": 2.0,   # Double credits
		"story_points": 2.0
	}
}

## Default victory condition for new campaigns
const DEFAULT_VICTORY_CONDITION: String = "SURVIVE_10_TURNS"

## Helper function: Get adjusted target for difficulty
static func get_adjusted_target(base_target: int, difficulty: String, condition_type: String) -> int:
	## Calculate adjusted victory target based on difficulty setting
	##
	## Args:
	## base_target: Base victory threshold
	## difficulty: Difficulty setting (EASY, NORMAL, HARD, BRUTAL)
	## condition_type: Type of condition (turns, credits, story_points)
	##
	## Returns:
	## Adjusted target value
	var multiplier: float = 1.0

	if DIFFICULTY_MULTIPLIERS.has(difficulty):
		var difficulty_data: Dictionary = DIFFICULTY_MULTIPLIERS[difficulty]
		multiplier = difficulty_data.get(condition_type, 1.0)

	return ceili(base_target * multiplier)

## Helper function: Check if victory condition is met
static func check_victory_condition(condition_type: VictoryConditionType, current_value: int, target_value: int) -> bool:

	## Args:
	## 	condition_type: Type of victory condition
	## 	current_value: Current progress value
	## 	target_value: Target value to achieve
	##
	## Returns:
	## 	True if victory condition is met
	##
	return current_value >= target_value

## Helper function: Get achievement description
static func get_achievement_description(achievement_id: String) -> String:
	## Get description text for an achievement
	##
	## Args:
	## achievement_id: Achievement identifier key
	##
	## Returns:
	## Human-readable achievement description
	if ACHIEVEMENT_THRESHOLDS.has(achievement_id):
		var achievement: Dictionary = ACHIEVEMENT_THRESHOLDS[achievement_id]
		return achievement.get("description", "Unknown achievement")

	return "Unknown achievement"

## Helper function: Check if achievement is unlocked
static func check_achievement(achievement_id: String, current_value: int) -> bool:

	## Args:
	## 	achievement_id: Achievement identifier key
	## 	current_value: Current value to check against threshold
	##
	## Returns:
	## 	True if achievement is unlocked
	##
	if not ACHIEVEMENT_THRESHOLDS.has(achievement_id):
		return false

	var achievement: Dictionary = ACHIEVEMENT_THRESHOLDS[achievement_id]
	var threshold: int = achievement.get("threshold", 0)
	var check_type: String = achievement.get("check_type", "")

	# Special case: Iron Will checks for ZERO casualties
	if check_type == "casualties":
		return current_value == 0

	# All other achievements check if current >= threshold
	return current_value >= threshold

## Helper function: Get completion percentage
static func get_completion_percentage(current_value: int, target_value: int) -> float:
	## Calculate campaign completion percentage
	##
	## Args:
	## current_value: Current progress value
	## target_value: Target value for victory
	##
	## Returns:
	## Completion percentage (0.0 to 100.0)
	if target_value <= 0:
		return 0.0

	var percentage: float = (float(current_value) / float(target_value)) * 100.0
	return clampf(percentage, 0.0, 100.0)

## Helper function: Get all unlocked achievements
static func get_unlocked_achievements(campaign_data: Dictionary) -> Array[String]:

	## Args:
	## 	campaign_data: Dictionary with campaign statistics
	##
	## Returns:
	## 	Array of achievement ID strings that have been unlocked
	##
	var unlocked: Array[String] = []

	# Check each achievement
	for achievement_id in ACHIEVEMENT_THRESHOLDS.keys():
		var achievement: Dictionary = ACHIEVEMENT_THRESHOLDS[achievement_id]
		var check_type: String = achievement.get("check_type", "")
		var current_value: int = 0

		# Get current value based on check type
		match check_type:
			"credits":
				current_value = campaign_data.get("credits", 0)
			"crew_size":
				var crew: Array = campaign_data.get("crew", [])
				current_value = crew.size()
			"captain_xp":
				var captain: Dictionary = campaign_data.get("captain", {})
				current_value = captain.get("experience", 0)
			"casualties":
				current_value = campaign_data.get("total_casualties", 0)
			"weapon_count":
				var equipment: Array = campaign_data.get("equipment", [])
				current_value = equipment.size()  # Simplified - should filter weapons
			"turns":
				current_value = campaign_data.get("current_turn", 0)

		if check_achievement(achievement_id, current_value):
			unlocked.append(achievement_id)

	return unlocked
