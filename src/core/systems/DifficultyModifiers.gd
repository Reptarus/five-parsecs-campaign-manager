class_name DifficultyModifiers
extends RefCounted

## Campaign Difficulty Modifiers System for Five Parsecs Campaign Manager
##
## Implements all difficulty level modifiers from Five Parsecs core rules (p.65).
## Provides centralized logic for difficulty-based gameplay adjustments.
##
## DIFFICULTY LEVELS:
## 1. STORY (Easy) - +1 XP per battle, basic victory conditions only
## 2. STANDARD (Normal) - Default rules, no modifications
## 3. CHALLENGING - Reroll enemy dice showing 1 or 2
## 4. HARDCORE - +1 enemy per battle, -1 starting story points, -2 rival resistance
## 5. NIGHTMARE (Insanity) - +1 specialist per battle, +3 invasion rolls, -3 initiative, NO story points
##
## Usage:
##   var xp_bonus = DifficultyModifiers.get_xp_bonus(difficulty_level)
##   var can_earn_story_points = not DifficultyModifiers.are_story_points_disabled(difficulty_level)

# MARK: - Public API - XP & Progression

## Get XP bonus awarded after each battle based on difficulty level.
## Returns:
##   +1 for STORY mode, 0 for all other difficulties
static func get_xp_bonus(difficulty: int) -> int:
	if difficulty == GlobalEnums.DifficultyLevel.STORY:
		return 1
	return 0

## Get description of XP bonus for UI display
static func get_xp_bonus_description(difficulty: int) -> String:
	var bonus = get_xp_bonus(difficulty)
	if bonus > 0:
		return "+%d XP after each battle" % bonus
	return "Standard XP progression"

# MARK: - Public API - Enemy Generation

## Get enemy count modifier for battle generation.
## Returns:
##   +1 for HARDCORE, 0 for other difficulties (NIGHTMARE uses specialist modifier instead)
static func get_enemy_count_modifier(difficulty: int) -> int:
	if difficulty == GlobalEnums.DifficultyLevel.HARDCORE:
		return 1
	return 0

## Check if low enemy dice rolls should be rerolled (CHALLENGING mode).
## Returns:
##   true for CHALLENGING difficulty, false otherwise
static func should_reroll_low_enemy_dice(difficulty: int) -> bool:
	return difficulty == GlobalEnums.DifficultyLevel.CHALLENGING

## Get specialist enemy modifier (NIGHTMARE mode only).
## Returns:
##   +1 for NIGHTMARE, 0 otherwise
static func get_specialist_enemy_modifier(difficulty: int) -> int:
	if difficulty == GlobalEnums.DifficultyLevel.NIGHTMARE:
		return 1
	return 0

## Get complete enemy generation modifiers for a difficulty level.
## Returns Dictionary with all enemy-related modifiers.
static func get_enemy_generation_modifiers(difficulty: int) -> Dictionary:
	return {
		"base_enemy_count_modifier": get_enemy_count_modifier(difficulty),
		"reroll_low_dice": should_reroll_low_enemy_dice(difficulty),
		"specialist_modifier": get_specialist_enemy_modifier(difficulty),
		"description": _get_enemy_modifier_description(difficulty)
	}

# MARK: - Public API - Story Points

## Get starting story points modifier.
## Returns:
##   -1 for HARDCORE, -999 for NIGHTMARE (disabled), 0 otherwise
static func get_starting_story_points_modifier(difficulty: int) -> int:
	if difficulty == GlobalEnums.DifficultyLevel.NIGHTMARE:
		return -999 # Story points disabled entirely
	elif difficulty == GlobalEnums.DifficultyLevel.HARDCORE:
		return -1
	return 0

## Check if story points are completely disabled (NIGHTMARE mode).
## Returns:
##   true for NIGHTMARE difficulty, false otherwise
static func are_story_points_disabled(difficulty: int) -> bool:
	return difficulty == GlobalEnums.DifficultyLevel.NIGHTMARE

## Get maximum story points allowed for difficulty level.
## Returns:
##   0 for NIGHTMARE (disabled), standard max (10) otherwise
static func get_max_story_points(difficulty: int) -> int:
	if are_story_points_disabled(difficulty):
		return 0
	return 10 # Five Parsecs standard maximum

## Apply starting story points modifier to a campaign.
## Returns the final story point count after modifier applied.
static func apply_starting_story_points_modifier(base_story_points: int, difficulty: int) -> int:
	if are_story_points_disabled(difficulty):
		return 0

	var modifier = get_starting_story_points_modifier(difficulty)
	return maxi(0, base_story_points + modifier)

# MARK: - Public API - Battle Mechanics

## Get Invasion roll modifier (for Invasion battles).
## Returns:
##   +3 for NIGHTMARE, 0 otherwise
static func get_invasion_roll_modifier(difficulty: int) -> int:
	if difficulty == GlobalEnums.DifficultyLevel.NIGHTMARE:
		return 3
	return 0

## Get Seize the Initiative roll modifier.
## Returns:
##   -3 for NIGHTMARE, 0 otherwise
static func get_seize_initiative_modifier(difficulty: int) -> int:
	if difficulty == GlobalEnums.DifficultyLevel.NIGHTMARE:
		return -3
	return 0

## Get Rival resistance roll modifier (for Rival battles).
## Returns:
##   -2 for HARDCORE, 0 otherwise (NIGHTMARE doesn't modify rivals)
static func get_rival_resistance_modifier(difficulty: int) -> int:
	if difficulty == GlobalEnums.DifficultyLevel.HARDCORE:
		return -2
	return 0

# MARK: - Public API - Victory Conditions

## Check if only basic victory conditions are available (STORY mode).
## Returns:
##   true for STORY difficulty, false otherwise
static func are_only_basic_victory_conditions_available(difficulty: int) -> bool:
	return difficulty == GlobalEnums.DifficultyLevel.STORY

## Get list of allowed victory condition types for difficulty level.
## Returns array of GlobalEnums.FiveParsecsCampaignVictoryType values.
static func get_allowed_victory_conditions(difficulty: int) -> Array[int]:
	var allowed: Array[int] = []

	if are_only_basic_victory_conditions_available(difficulty):
		# STORY mode: Only basic victory conditions (simpler targets)
		allowed.append(GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20)
		allowed.append(GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20)
		allowed.append(GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K)
	else:
		# All other modes: All victory conditions available
		# Return all enum values (dynamically get from GlobalEnums)
		for i in range(GlobalEnums.FiveParsecsCampaignVictoryType.size()):
			allowed.append(i)

	return allowed

# MARK: - Public API - Comprehensive Modifier Queries

## Get all modifiers for a difficulty level as a complete dictionary.
## Useful for displaying in UI or applying all modifiers at once.
static func get_all_modifiers(difficulty: int) -> Dictionary:
	return {
		"difficulty_level": difficulty,
		"difficulty_name": _get_difficulty_name(difficulty),

		# XP & Progression
		"xp_bonus": get_xp_bonus(difficulty),
		"xp_description": get_xp_bonus_description(difficulty),

		# Enemy Generation
		"enemy_count_modifier": get_enemy_count_modifier(difficulty),
		"reroll_low_enemy_dice": should_reroll_low_enemy_dice(difficulty),
		"specialist_enemy_modifier": get_specialist_enemy_modifier(difficulty),

		# Story Points
		"starting_story_points_modifier": get_starting_story_points_modifier(difficulty),
		"story_points_disabled": are_story_points_disabled(difficulty),
		"max_story_points": get_max_story_points(difficulty),

		# Battle Mechanics
		"invasion_roll_modifier": get_invasion_roll_modifier(difficulty),
		"seize_initiative_modifier": get_seize_initiative_modifier(difficulty),
		"rival_resistance_modifier": get_rival_resistance_modifier(difficulty),

		# Victory Conditions
		"only_basic_victory_conditions": are_only_basic_victory_conditions_available(difficulty),
		"allowed_victory_conditions": get_allowed_victory_conditions(difficulty),

		# Summary
		"summary": get_difficulty_summary(difficulty)
	}

## Get human-readable summary of difficulty modifiers for UI display.
static func get_difficulty_summary(difficulty: int) -> String:
	match difficulty:
		GlobalEnums.DifficultyLevel.STORY:
			return "Easy mode: +1 XP per battle, basic victory conditions only"

		GlobalEnums.DifficultyLevel.STANDARD:
			return "Standard rules with no modifications"

		GlobalEnums.DifficultyLevel.CHALLENGING:
			return "Increased challenge: Reroll enemy dice showing 1 or 2"

		GlobalEnums.DifficultyLevel.HARDCORE:
			return "Hard mode: +1 enemy per battle, -1 starting story point, -2 rival resistance"

		GlobalEnums.DifficultyLevel.NIGHTMARE:
			return "Extreme difficulty: +1 specialist per battle, +3 invasion rolls, -3 initiative, NO story points"

		_:
			return "Unknown difficulty level"

## Get detailed description with all modifiers listed.
static func get_difficulty_detailed_description(difficulty: int) -> String:
	var details: Array[String] = []
	var modifiers = get_all_modifiers(difficulty)

	details.append("Difficulty: %s" % modifiers.difficulty_name)
	details.append("")

	# XP Modifiers
	if modifiers.xp_bonus != 0:
		details.append("• XP Bonus: %s" % modifiers.xp_description)

	# Enemy Modifiers
	if modifiers.enemy_count_modifier != 0:
		details.append("• Enemy Count: +%d per battle" % modifiers.enemy_count_modifier)

	if modifiers.reroll_low_enemy_dice:
		details.append("• Enemy Dice: Reroll results of 1-2")

	if modifiers.specialist_enemy_modifier != 0:
		details.append("• Specialist Enemies: +%d per battle" % modifiers.specialist_enemy_modifier)

	# Story Point Modifiers
	if modifiers.story_points_disabled:
		details.append("• Story Points: DISABLED")
	elif modifiers.starting_story_points_modifier != 0:
		details.append("• Starting Story Points: %+d" % modifiers.starting_story_points_modifier)

	# Battle Modifiers
	if modifiers.invasion_roll_modifier != 0:
		details.append("• Invasion Rolls: %+d" % modifiers.invasion_roll_modifier)

	if modifiers.seize_initiative_modifier != 0:
		details.append("• Seize Initiative: %+d" % modifiers.seize_initiative_modifier)

	if modifiers.rival_resistance_modifier != 0:
		details.append("• Rival Resistance: %+d" % modifiers.rival_resistance_modifier)

	# Victory Conditions
	if modifiers.only_basic_victory_conditions:
		details.append("• Victory Conditions: Basic only")

	if details.size() == 2: # Only header + empty line
		details.append("• No special modifiers (standard rules)")

	return "\n".join(details)

# MARK: - Public API - Validation

## Validate if a difficulty level is valid.
static func is_valid_difficulty(difficulty: int) -> bool:
	return difficulty >= GlobalEnums.DifficultyLevel.NONE and \
		   difficulty <= GlobalEnums.DifficultyLevel.NIGHTMARE

## Get default difficulty level (STANDARD).
static func get_default_difficulty() -> int:
	return GlobalEnums.DifficultyLevel.STANDARD

# MARK: - Private Helpers

static func _get_difficulty_name(difficulty: int) -> String:
	match difficulty:
		GlobalEnums.DifficultyLevel.NONE:
			return "None"
		GlobalEnums.DifficultyLevel.STORY:
			return "Story (Easy)"
		GlobalEnums.DifficultyLevel.STANDARD:
			return "Standard (Normal)"
		GlobalEnums.DifficultyLevel.CHALLENGING:
			return "Challenging"
		GlobalEnums.DifficultyLevel.HARDCORE:
			return "Hardcore"
		GlobalEnums.DifficultyLevel.NIGHTMARE:
			return "Nightmare (Insanity)"
		_:
			return "Unknown"

static func _get_enemy_modifier_description(difficulty: int) -> String:
	match difficulty:
		GlobalEnums.DifficultyLevel.STORY:
			return "Standard enemy generation"
		GlobalEnums.DifficultyLevel.STANDARD:
			return "Standard enemy generation"
		GlobalEnums.DifficultyLevel.CHALLENGING:
			return "Reroll enemy dice showing 1 or 2 (increases minimum enemy count)"
		GlobalEnums.DifficultyLevel.HARDCORE:
			return "+1 basic enemy added to every battle"
		GlobalEnums.DifficultyLevel.NIGHTMARE:
			return "+1 specialist enemy added to every battle (higher threat)"
		_:
			return "Unknown difficulty"

# MARK: - Integration Helpers for Existing Systems

## Calculate final enemy count with difficulty modifier applied.
## Used by EnemyGenerator.gd during battle setup.
static func calculate_final_enemy_count(base_count: int, difficulty: int) -> int:
	return base_count + get_enemy_count_modifier(difficulty)

## Check if an enemy dice roll should be rerolled (for CHALLENGING mode).
## Used by EnemyGenerator during enemy number determination.
static func should_reroll_enemy_die(die_result: int, difficulty: int) -> bool:
	if not should_reroll_low_enemy_dice(difficulty):
		return false

	return die_result <= 2 # Reroll 1s and 2s

## Calculate final invasion roll with difficulty modifier.
## Used by battle setup systems when generating Invasion battles.
static func calculate_invasion_roll(base_roll: int, difficulty: int) -> int:
	return base_roll + get_invasion_roll_modifier(difficulty)

## Calculate final Seize the Initiative roll with difficulty modifier.
## Used by SeizeInitiativeSystem.gd during battle start.
static func calculate_seize_initiative_roll(base_roll: int, difficulty: int) -> int:
	return base_roll + get_seize_initiative_modifier(difficulty)

## Calculate final rival resistance roll with difficulty modifier.
## Used by rival battle generation systems.
static func calculate_rival_resistance_roll(base_roll: int, difficulty: int) -> int:
	return base_roll + get_rival_resistance_modifier(difficulty)
