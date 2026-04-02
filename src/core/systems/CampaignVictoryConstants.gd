class_name CampaignVictoryConstants
## Campaign Victory Constants for Five Parsecs Campaign Manager
## Data loaded from res://data/victory_conditions.json (Core Rules pp.63-64)
##
## Usage: Reference these constants in campaign state validation and victory checking
## Architecture: Lazy-loads JSON data, keeps enums and static helper API

## Victory condition types
enum VictoryConditionType {
	SURVIVE_TURNS,
	STORY_POINTS,
	WEALTH,
	REPUTATION,
	CREW_SIZE,
	DEFEAT_RIVAL,
	CUSTOM
}

const _DATA_PATH := "res://data/victory_conditions.json"

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("CampaignVictoryConstants: Failed to open %s" % _DATA_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	else:
		push_error("CampaignVictoryConstants: Failed to parse %s" % _DATA_PATH)
	file.close()


## Backward-compatible property accessors

## Primary victory conditions — these are app-defined condition templates,
## not the Core Rules conditions (which are in _data["conditions"])
static var PRIMARY_VICTORY_CONDITIONS: Dictionary:
	get:
		_ensure_loaded()
		# Build from known condition types with defaults
		return {
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

static var ACHIEVEMENT_THRESHOLDS: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("achievement_thresholds", {})

static var COMMON_TARGET_TURNS: Array[int]:
	get:
		_ensure_loaded()
		var raw: Array = _data.get("common_target_turns", [5, 10, 15, 20, 30, 50])
		var result: Array[int] = []
		for item in raw:
			result.append(int(item))
		return result

static var DIFFICULTY_MULTIPLIERS: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("difficulty_multipliers", {})

const DEFAULT_VICTORY_CONDITION: String = "SURVIVE_10_TURNS"


## Helper functions (unchanged public API)

static func get_adjusted_target(
	base_target: int, difficulty: String, condition_type: String
) -> int:
	var multiplier: float = 1.0
	if DIFFICULTY_MULTIPLIERS.has(difficulty):
		var difficulty_data: Dictionary = DIFFICULTY_MULTIPLIERS[difficulty]
		multiplier = difficulty_data.get(condition_type, 1.0)
	return ceili(base_target * multiplier)

static func check_victory_condition(
	condition_type: VictoryConditionType,
	current_value: int,
	target_value: int,
) -> bool:
	return current_value >= target_value

static func get_achievement_description(achievement_id: String) -> String:
	if ACHIEVEMENT_THRESHOLDS.has(achievement_id):
		var achievement: Dictionary = ACHIEVEMENT_THRESHOLDS[achievement_id]
		return achievement.get("description", "Unknown achievement")
	return "Unknown achievement"

static func check_achievement(
	achievement_id: String, current_value: int
) -> bool:
	if not ACHIEVEMENT_THRESHOLDS.has(achievement_id):
		return false
	var achievement: Dictionary = ACHIEVEMENT_THRESHOLDS[achievement_id]
	var threshold: int = int(achievement.get("threshold", 0))
	var check_type: String = achievement.get("check_type", "")
	if check_type == "casualties":
		return current_value == 0
	return current_value >= threshold

static func get_completion_percentage(
	current_value: int, target_value: int
) -> float:
	if target_value <= 0:
		return 0.0
	var percentage: float = (float(current_value) / float(target_value)) * 100.0
	return clampf(percentage, 0.0, 100.0)

static func get_unlocked_achievements(
	campaign_data: Dictionary,
) -> Array[String]:
	var unlocked: Array[String] = []
	for achievement_id in ACHIEVEMENT_THRESHOLDS.keys():
		var achievement: Dictionary = ACHIEVEMENT_THRESHOLDS[achievement_id]
		var check_type: String = achievement.get("check_type", "")
		var current_value: int = 0
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
				current_value = equipment.size()
			"turns":
				current_value = campaign_data.get("current_turn", 0)
		if check_achievement(achievement_id, current_value):
			unlocked.append(achievement_id)
	return unlocked
