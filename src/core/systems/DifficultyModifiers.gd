class_name DifficultyModifiers
extends RefCounted

## Campaign Difficulty Modifiers System for Five Parsecs Campaign Manager
##
## Implements all difficulty level modifiers from Five Parsecs core rules (p.65).
## All numeric values loaded from data/difficulty_modifiers.json — see that file
## for the canonical per-level values.
##
## Usage:
##   var xp_bonus = DifficultyModifiers.get_xp_bonus(difficulty_level)
##   var can_earn_story_points = not DifficultyModifiers.are_story_points_disabled(difficulty_level)

# MARK: - JSON Data Loading

## Maps DifficultyLevel enum ordinals to JSON key names.
## Order MUST match GlobalEnums.DifficultyLevel: NONE=0, EASY=1, NORMAL=2, HARD=3,
## CHALLENGING=4, NIGHTMARE=5, HARDCORE=6, ELITE=7, INSANITY=8
const _LEVEL_KEYS: Array[String] = [
	"NONE", "EASY", "NORMAL", "HARD", "CHALLENGING",
	"NIGHTMARE", "HARDCORE", "ELITE", "INSANITY"
]

static var _levels: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open("res://data/difficulty_modifiers.json", FileAccess.READ)
	if not file:
		push_warning("DifficultyModifiers: Could not open difficulty_modifiers.json, using empty defaults")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_levels = json.data.get("difficulty_levels", {})
	file.close()

## Get the modifier dict for a difficulty level, with safe fallback.
static func _get_level_data(difficulty: int) -> Dictionary:
	_ensure_loaded()
	if difficulty >= 0 and difficulty < _LEVEL_KEYS.size():
		var key: String = _LEVEL_KEYS[difficulty]
		if key in _levels:
			return _levels[key]
	return {}

# MARK: - Public API - XP & Progression

static func get_xp_bonus(difficulty: int) -> int:
	return int(_get_level_data(difficulty).get("xp_bonus", 0))

static func get_xp_bonus_description(difficulty: int) -> String:
	var bonus := get_xp_bonus(difficulty)
	if bonus > 0:
		return "+%d XP after each battle" % bonus
	return "Standard XP progression"

# MARK: - Public API - Enemy Generation

static func get_enemy_count_modifier(difficulty: int) -> int:
	return int(_get_level_data(difficulty).get("enemy_count_modifier", 0))

static func should_reroll_low_enemy_dice(difficulty: int) -> bool:
	return bool(_get_level_data(difficulty).get("reroll_low_enemy_dice", false))

static func get_specialist_enemy_modifier(difficulty: int) -> int:
	return int(_get_level_data(difficulty).get("specialist_enemy_modifier", 0))

static func get_enemy_generation_modifiers(difficulty: int) -> Dictionary:
	return {
		"base_enemy_count_modifier": get_enemy_count_modifier(difficulty),
		"reroll_low_dice": should_reroll_low_enemy_dice(difficulty),
		"specialist_modifier": get_specialist_enemy_modifier(difficulty),
		"description": _get_enemy_modifier_description(difficulty)
	}

# MARK: - Public API - Story Points

static func get_starting_story_points_modifier(difficulty: int) -> int:
	return int(_get_level_data(difficulty).get("starting_story_points_modifier", 0))

static func are_story_points_disabled(difficulty: int) -> bool:
	return bool(_get_level_data(difficulty).get("story_points_disabled", false))

static func get_max_story_points(difficulty: int) -> int:
	return int(_get_level_data(difficulty).get("max_story_points", 10))

static func apply_starting_story_points_modifier(base_story_points: int, difficulty: int) -> int:
	if are_story_points_disabled(difficulty):
		return 0
	var modifier := get_starting_story_points_modifier(difficulty)
	return maxi(0, base_story_points + modifier)

# MARK: - Public API - Battle Mechanics

static func get_invasion_roll_modifier(difficulty: int) -> int:
	return int(_get_level_data(difficulty).get("invasion_roll_modifier", 0))

static func get_seize_initiative_modifier(difficulty: int) -> int:
	return int(_get_level_data(difficulty).get("seize_initiative_modifier", 0))

static func get_rival_resistance_modifier(difficulty: int) -> int:
	return int(_get_level_data(difficulty).get("rival_resistance_modifier", 0))

# MARK: - Public API - Unique Individual (Core Rules pp.64-65)

static func get_unique_individual_roll_modifier(difficulty: int) -> int:
	return int(_get_level_data(difficulty).get("unique_individual_roll_modifier", 0))

static func is_unique_individual_forced(difficulty: int) -> bool:
	return bool(_get_level_data(difficulty).get("unique_individual_forced", false))

static func can_have_double_unique_individual(difficulty: int) -> bool:
	return bool(_get_level_data(difficulty).get("double_unique_possible", false))

# MARK: - Public API - Easy Mode Enemy Reduction

static func get_easy_enemy_reduction(total_enemies: int, difficulty: int) -> int:
	var threshold := int(_get_level_data(difficulty).get("easy_enemy_reduction_threshold", 0))
	if threshold > 0 and total_enemies >= threshold:
		return 1
	return 0

# MARK: - Public API - Stars of the Story

static func are_stars_of_story_disabled(difficulty: int) -> bool:
	return bool(_get_level_data(difficulty).get("stars_of_story_disabled", false))

# MARK: - Public API - Victory Conditions

static func are_only_basic_victory_conditions_available(difficulty: int) -> bool:
	return bool(_get_level_data(difficulty).get("only_basic_victory_conditions", false))

static func get_allowed_victory_conditions(difficulty: int) -> Array[int]:
	var allowed: Array[int] = []
	if are_only_basic_victory_conditions_available(difficulty):
		allowed.append(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20)
		allowed.append(GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20)
		allowed.append(GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K)
	else:
		for i in range(GlobalEnums.FiveParsecsCampaignVictoryType.size()):
			allowed.append(i)
	return allowed

# MARK: - Public API - Comprehensive Modifier Queries

static func get_all_modifiers(difficulty: int) -> Dictionary:
	return {
		"difficulty_level": difficulty,
		"difficulty_name": _get_difficulty_name(difficulty),
		"xp_bonus": get_xp_bonus(difficulty),
		"xp_description": get_xp_bonus_description(difficulty),
		"enemy_count_modifier": get_enemy_count_modifier(difficulty),
		"reroll_low_enemy_dice": should_reroll_low_enemy_dice(difficulty),
		"specialist_enemy_modifier": get_specialist_enemy_modifier(difficulty),
		"starting_story_points_modifier": get_starting_story_points_modifier(difficulty),
		"story_points_disabled": are_story_points_disabled(difficulty),
		"max_story_points": get_max_story_points(difficulty),
		"invasion_roll_modifier": get_invasion_roll_modifier(difficulty),
		"seize_initiative_modifier": get_seize_initiative_modifier(difficulty),
		"rival_resistance_modifier": get_rival_resistance_modifier(difficulty),
		"unique_individual_roll_modifier": get_unique_individual_roll_modifier(difficulty),
		"unique_individual_forced": is_unique_individual_forced(difficulty),
		"double_unique_possible": can_have_double_unique_individual(difficulty),
		"stars_of_story_disabled": are_stars_of_story_disabled(difficulty),
		"only_basic_victory_conditions": are_only_basic_victory_conditions_available(difficulty),
		"allowed_victory_conditions": get_allowed_victory_conditions(difficulty),
		"summary": get_difficulty_summary(difficulty)
	}

static func get_difficulty_summary(difficulty: int) -> String:
	var data := _get_level_data(difficulty)
	if data.is_empty():
		return "Unknown difficulty level"
	var parts: Array[String] = []
	var name := _get_difficulty_name(difficulty)
	if int(data.get("xp_bonus", 0)) > 0:
		parts.append("+%d XP per battle" % int(data.get("xp_bonus", 0)))
	if bool(data.get("only_basic_victory_conditions", false)):
		parts.append("basic victory conditions only")
	if bool(data.get("reroll_low_enemy_dice", false)):
		parts.append("reroll enemy dice 1-2")
	if int(data.get("enemy_count_modifier", 0)) > 0:
		parts.append("+%d enemy" % int(data.get("enemy_count_modifier", 0)))
	if int(data.get("specialist_enemy_modifier", 0)) > 0:
		parts.append("+%d specialist" % int(data.get("specialist_enemy_modifier", 0)))
	if bool(data.get("unique_individual_forced", false)):
		parts.append("forced Unique Individual")
	if int(data.get("invasion_roll_modifier", 0)) != 0:
		parts.append("%+d invasion" % int(data.get("invasion_roll_modifier", 0)))
	if int(data.get("seize_initiative_modifier", 0)) != 0:
		parts.append("%+d initiative" % int(data.get("seize_initiative_modifier", 0)))
	if bool(data.get("story_points_disabled", false)):
		parts.append("NO story points")
	elif int(data.get("starting_story_points_modifier", 0)) != 0:
		parts.append("%+d starting story points" % int(data.get("starting_story_points_modifier", 0)))
	if int(data.get("rival_resistance_modifier", 0)) != 0:
		parts.append("%+d rival resistance" % int(data.get("rival_resistance_modifier", 0)))
	if bool(data.get("stars_of_story_disabled", false)):
		parts.append("NO Stars of the Story")
	if parts.is_empty():
		return "%s: Standard rules with no modifications" % name
	return "%s: %s" % [name, ", ".join(parts)]

static func get_difficulty_detailed_description(difficulty: int) -> String:
	var details: Array[String] = []
	var modifiers := get_all_modifiers(difficulty)
	details.append("Difficulty: %s" % modifiers.difficulty_name)
	details.append("")
	if modifiers.xp_bonus != 0:
		details.append("• XP Bonus: %s" % modifiers.xp_description)
	if modifiers.enemy_count_modifier != 0:
		details.append("• Enemy Count: +%d per battle" % modifiers.enemy_count_modifier)
	if modifiers.reroll_low_enemy_dice:
		details.append("• Enemy Dice: Reroll results of 1-2")
	if modifiers.specialist_enemy_modifier != 0:
		details.append("• Specialist Enemies: +%d per battle" % modifiers.specialist_enemy_modifier)
	if modifiers.story_points_disabled:
		details.append("• Story Points: DISABLED")
	elif modifiers.starting_story_points_modifier != 0:
		details.append("• Starting Story Points: %+d" % modifiers.starting_story_points_modifier)
	if modifiers.invasion_roll_modifier != 0:
		details.append("• Invasion Rolls: %+d" % modifiers.invasion_roll_modifier)
	if modifiers.seize_initiative_modifier != 0:
		details.append("• Seize Initiative: %+d" % modifiers.seize_initiative_modifier)
	if modifiers.rival_resistance_modifier != 0:
		details.append("• Rival Resistance: %+d" % modifiers.rival_resistance_modifier)
	if modifiers.unique_individual_forced:
		details.append("• Unique Individual: FORCED in every battle")
		if modifiers.double_unique_possible:
			details.append("• Double Unique: 2D6, on 11-12 TWO Unique Individuals")
	elif modifiers.unique_individual_roll_modifier != 0:
		details.append("• Unique Individual Roll: %+d" % modifiers.unique_individual_roll_modifier)
	if modifiers.stars_of_story_disabled:
		details.append("• Stars of the Story: DISABLED")
	if modifiers.only_basic_victory_conditions:
		details.append("• Victory Conditions: Basic only (Play 20 / Win 20)")
	if details.size() == 2:
		details.append("• No special modifiers (standard rules)")
	return "\n".join(details)

# MARK: - Public API - Validation

static func is_valid_difficulty(difficulty: int) -> bool:
	return difficulty >= 0 and difficulty < _LEVEL_KEYS.size()

static func get_default_difficulty() -> int:
	return GlobalEnums.DifficultyLevel.NORMAL

# MARK: - Private Helpers

static func _get_difficulty_name(difficulty: int) -> String:
	match difficulty:
		GlobalEnums.DifficultyLevel.NONE: return "None"
		GlobalEnums.DifficultyLevel.EASY: return "Story (Easy)"
		GlobalEnums.DifficultyLevel.NORMAL: return "Standard (Normal)"
		GlobalEnums.DifficultyLevel.HARD: return "Hard"
		GlobalEnums.DifficultyLevel.CHALLENGING: return "Challenging"
		GlobalEnums.DifficultyLevel.NIGHTMARE: return "Nightmare"
		GlobalEnums.DifficultyLevel.HARDCORE: return "Hardcore"
		GlobalEnums.DifficultyLevel.ELITE: return "Elite"
		GlobalEnums.DifficultyLevel.INSANITY: return "Insanity"
		_: return "Unknown"

static func _get_enemy_modifier_description(difficulty: int) -> String:
	var data := _get_level_data(difficulty)
	if data.is_empty():
		return "Unknown difficulty"
	if bool(data.get("reroll_low_enemy_dice", false)):
		return "Reroll enemy dice showing 1 or 2 (increases minimum enemy count)"
	if int(data.get("specialist_enemy_modifier", 0)) > 0:
		return "+%d specialist enemy added to every battle (higher threat)" % int(data.get("specialist_enemy_modifier", 0))
	if int(data.get("enemy_count_modifier", 0)) > 0:
		return "+%d basic enemy added to every battle" % int(data.get("enemy_count_modifier", 0))
	return "Standard enemy generation"

# MARK: - Integration Helpers for Existing Systems

static func calculate_final_enemy_count(base_count: int, difficulty: int) -> int:
	return base_count + get_enemy_count_modifier(difficulty)

static func should_reroll_enemy_die(die_result: int, difficulty: int) -> bool:
	if not should_reroll_low_enemy_dice(difficulty):
		return false
	return die_result <= 2

static func calculate_invasion_roll(base_roll: int, difficulty: int) -> int:
	return base_roll + get_invasion_roll_modifier(difficulty)

static func calculate_seize_initiative_roll(base_roll: int, difficulty: int) -> int:
	return base_roll + get_seize_initiative_modifier(difficulty)

static func calculate_rival_resistance_roll(base_roll: int, difficulty: int) -> int:
	return base_roll + get_rival_resistance_modifier(difficulty)
