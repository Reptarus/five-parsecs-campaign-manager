class_name CampaignVictoryConstants
## Campaign Victory Constants for Five Parsecs Campaign Manager
## Data loaded from res://data/victory_conditions.json (Core Rules pp.63-64)
##
## Lazy-loads the rule-faithful victory data and exposes a small static helper API.
##
## 2026-06-01 rules-accuracy consolidation: removed the fabricated VictoryConditionType
## enum, the PRIMARY_VICTORY_CONDITIONS templates, and the achievement/difficulty
## machinery (ACHIEVEMENT_THRESHOLDS / DIFFICULTY_MULTIPLIERS / get_adjusted_target /
## check_achievement / get_achievement_description / get_unlocked_achievements). The two
## JSON sections those read (achievement_thresholds, difficulty_multipliers) were deleted
## from victory_conditions.json in Sprint B, so the helpers had become silent no-ops and
## were only reached via the dev-only CampaignStateValidator path. The rule-faithful
## victory data still lives in victory_conditions.json under "conditions" (Core Rules p.64).

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


## Common campaign-length targets (Core Rules p.63), from victory_conditions.json.
static var COMMON_TARGET_TURNS: Array[int]:
	get:
		_ensure_loaded()
		var raw: Array = _data.get("common_target_turns", [5, 10, 15, 20, 30, 50])
		var result: Array[int] = []
		for item in raw:
			result.append(int(item))
		return result

const DEFAULT_VICTORY_CONDITION: String = "SURVIVE_10_TURNS"


## Helper functions (rule-faithful public API)

## Generic "is this condition met?" check. condition_type is accepted for call-site
## clarity, but every Core Rules victory condition is a simple threshold (current >= target).
static func check_victory_condition(
	condition_type: int,
	current_value: int,
	target_value: int,
) -> bool:
	return current_value >= target_value

static func get_completion_percentage(
	current_value: int, target_value: int
) -> float:
	if target_value <= 0:
		return 0.0
	var percentage: float = (float(current_value) / float(target_value)) * 100.0
	return clampf(percentage, 0.0, 100.0)
