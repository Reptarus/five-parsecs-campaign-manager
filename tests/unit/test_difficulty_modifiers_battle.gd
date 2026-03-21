extends GdUnitTestSuite
## Tests for DifficultyModifiers battle-affecting modifiers
## Covers the 6 NOT_TESTED battle modifiers from QA_CORE_RULES_TEST_PLAN.md §9a
## Core Rules Reference: p.64-65

const DifficultyModifiers := preload("res://src/core/systems/DifficultyModifiers.gd")
var GlobalEnumsRef

func before():
	GlobalEnumsRef = load("res://src/core/systems/GlobalEnums.gd")
	if not GlobalEnumsRef:
		push_warning("GlobalEnums failed to load")

func after():
	GlobalEnumsRef = null

# ============================================================================
# Enemy Count Modifier (HARDCORE: +1 basic enemy)
# ============================================================================

func test_enemy_count_easy_is_zero():
	assert_that(DifficultyModifiers.get_enemy_count_modifier(
		GlobalEnumsRef.DifficultyLevel.EASY)).is_equal(0)

func test_enemy_count_normal_is_zero():
	assert_that(DifficultyModifiers.get_enemy_count_modifier(
		GlobalEnumsRef.DifficultyLevel.NORMAL)).is_equal(0)

func test_enemy_count_challenging_is_zero():
	assert_that(DifficultyModifiers.get_enemy_count_modifier(
		GlobalEnumsRef.DifficultyLevel.CHALLENGING)).is_equal(0)

func test_enemy_count_hardcore_is_plus_one():
	assert_that(DifficultyModifiers.get_enemy_count_modifier(
		GlobalEnumsRef.DifficultyLevel.HARDCORE)).is_equal(1)

func test_enemy_count_insanity_is_zero():
	"""INSANITY uses specialist modifier, not base enemy count"""
	assert_that(DifficultyModifiers.get_enemy_count_modifier(
		GlobalEnumsRef.DifficultyLevel.INSANITY)).is_equal(0)

func test_specialist_enemy_insanity_is_plus_one():
	assert_that(DifficultyModifiers.get_specialist_enemy_modifier(
		GlobalEnumsRef.DifficultyLevel.INSANITY)).is_equal(1)

func test_specialist_enemy_hardcore_is_zero():
	assert_that(DifficultyModifiers.get_specialist_enemy_modifier(
		GlobalEnumsRef.DifficultyLevel.HARDCORE)).is_equal(0)

func test_calculate_final_enemy_count_hardcore():
	"""5 base enemies + HARDCORE (+1) = 6"""
	assert_that(DifficultyModifiers.calculate_final_enemy_count(
		5, GlobalEnumsRef.DifficultyLevel.HARDCORE)).is_equal(6)

func test_calculate_final_enemy_count_normal():
	"""5 base enemies + NORMAL (0) = 5"""
	assert_that(DifficultyModifiers.calculate_final_enemy_count(
		5, GlobalEnumsRef.DifficultyLevel.NORMAL)).is_equal(5)

# ============================================================================
# Easy Mode Enemy Reduction (remove 1 basic if 5+ enemies)
# ============================================================================

func test_easy_reduction_with_5_enemies():
	assert_that(DifficultyModifiers.get_easy_enemy_reduction(
		5, GlobalEnumsRef.DifficultyLevel.EASY)).is_equal(1)

func test_easy_reduction_with_4_enemies():
	"""Below threshold — no reduction"""
	assert_that(DifficultyModifiers.get_easy_enemy_reduction(
		4, GlobalEnumsRef.DifficultyLevel.EASY)).is_equal(0)

func test_easy_reduction_normal_mode():
	"""Only applies to EASY mode"""
	assert_that(DifficultyModifiers.get_easy_enemy_reduction(
		5, GlobalEnumsRef.DifficultyLevel.NORMAL)).is_equal(0)

# ============================================================================
# Reroll Low Enemy Dice (CHALLENGING: reroll 1s and 2s)
# ============================================================================

func test_reroll_challenging_enabled():
	assert_that(DifficultyModifiers.should_reroll_low_enemy_dice(
		GlobalEnumsRef.DifficultyLevel.CHALLENGING)).is_true()

func test_reroll_normal_disabled():
	assert_that(DifficultyModifiers.should_reroll_low_enemy_dice(
		GlobalEnumsRef.DifficultyLevel.NORMAL)).is_false()

func test_reroll_hardcore_disabled():
	"""HARDCORE adds enemies, doesn't reroll"""
	assert_that(DifficultyModifiers.should_reroll_low_enemy_dice(
		GlobalEnumsRef.DifficultyLevel.HARDCORE)).is_false()

func test_should_reroll_die_result_1():
	assert_that(DifficultyModifiers.should_reroll_enemy_die(
		1, GlobalEnumsRef.DifficultyLevel.CHALLENGING)).is_true()

func test_should_reroll_die_result_2():
	assert_that(DifficultyModifiers.should_reroll_enemy_die(
		2, GlobalEnumsRef.DifficultyLevel.CHALLENGING)).is_true()

func test_should_not_reroll_die_result_3():
	assert_that(DifficultyModifiers.should_reroll_enemy_die(
		3, GlobalEnumsRef.DifficultyLevel.CHALLENGING)).is_false()

func test_should_not_reroll_normal_mode():
	assert_that(DifficultyModifiers.should_reroll_enemy_die(
		1, GlobalEnumsRef.DifficultyLevel.NORMAL)).is_false()

# ============================================================================
# Invasion Roll Modifier (HARDCORE: +2, INSANITY: +3)
# ============================================================================

func test_invasion_easy_is_zero():
	assert_that(DifficultyModifiers.get_invasion_roll_modifier(
		GlobalEnumsRef.DifficultyLevel.EASY)).is_equal(0)

func test_invasion_normal_is_zero():
	assert_that(DifficultyModifiers.get_invasion_roll_modifier(
		GlobalEnumsRef.DifficultyLevel.NORMAL)).is_equal(0)

func test_invasion_challenging_is_zero():
	assert_that(DifficultyModifiers.get_invasion_roll_modifier(
		GlobalEnumsRef.DifficultyLevel.CHALLENGING)).is_equal(0)

func test_invasion_hardcore_is_plus_two():
	assert_that(DifficultyModifiers.get_invasion_roll_modifier(
		GlobalEnumsRef.DifficultyLevel.HARDCORE)).is_equal(2)

func test_invasion_insanity_is_plus_three():
	assert_that(DifficultyModifiers.get_invasion_roll_modifier(
		GlobalEnumsRef.DifficultyLevel.INSANITY)).is_equal(3)

func test_calculate_invasion_roll_hardcore():
	"""Base roll 7 + HARDCORE (+2) = 9 (meets threshold)"""
	assert_that(DifficultyModifiers.calculate_invasion_roll(
		7, GlobalEnumsRef.DifficultyLevel.HARDCORE)).is_equal(9)

# ============================================================================
# Seize Initiative Modifier (HARDCORE: -2, INSANITY: -3)
# ============================================================================

func test_initiative_easy_is_zero():
	assert_that(DifficultyModifiers.get_seize_initiative_modifier(
		GlobalEnumsRef.DifficultyLevel.EASY)).is_equal(0)

func test_initiative_normal_is_zero():
	assert_that(DifficultyModifiers.get_seize_initiative_modifier(
		GlobalEnumsRef.DifficultyLevel.NORMAL)).is_equal(0)

func test_initiative_hardcore_is_minus_two():
	assert_that(DifficultyModifiers.get_seize_initiative_modifier(
		GlobalEnumsRef.DifficultyLevel.HARDCORE)).is_equal(-2)

func test_initiative_insanity_is_minus_three():
	assert_that(DifficultyModifiers.get_seize_initiative_modifier(
		GlobalEnumsRef.DifficultyLevel.INSANITY)).is_equal(-3)

func test_calculate_initiative_roll_hardcore():
	"""Base roll 5 + HARDCORE (-2) = 3 (fails 4+ threshold)"""
	assert_that(DifficultyModifiers.calculate_seize_initiative_roll(
		5, GlobalEnumsRef.DifficultyLevel.HARDCORE)).is_equal(3)

func test_calculate_initiative_roll_insanity():
	"""Base roll 5 + INSANITY (-3) = 2 (fails 4+ threshold)"""
	assert_that(DifficultyModifiers.calculate_seize_initiative_roll(
		5, GlobalEnumsRef.DifficultyLevel.INSANITY)).is_equal(2)

# ============================================================================
# Rival Resistance Modifier (HARDCORE: -2)
# ============================================================================

func test_rival_resistance_normal_is_zero():
	assert_that(DifficultyModifiers.get_rival_resistance_modifier(
		GlobalEnumsRef.DifficultyLevel.NORMAL)).is_equal(0)

func test_rival_resistance_hardcore_is_minus_two():
	assert_that(DifficultyModifiers.get_rival_resistance_modifier(
		GlobalEnumsRef.DifficultyLevel.HARDCORE)).is_equal(-2)

func test_rival_resistance_insanity_is_zero():
	"""INSANITY does NOT modify rival resistance per Core Rules"""
	assert_that(DifficultyModifiers.get_rival_resistance_modifier(
		GlobalEnumsRef.DifficultyLevel.INSANITY)).is_equal(0)

func test_calculate_rival_resistance_hardcore():
	"""Base roll 4 + HARDCORE (-2) = 2"""
	assert_that(DifficultyModifiers.calculate_rival_resistance_roll(
		4, GlobalEnumsRef.DifficultyLevel.HARDCORE)).is_equal(2)

# ============================================================================
# Unique Individual (HARDCORE: +1 roll, INSANITY: forced every battle)
# ============================================================================

func test_unique_individual_normal_modifier_zero():
	assert_that(DifficultyModifiers.get_unique_individual_roll_modifier(
		GlobalEnumsRef.DifficultyLevel.NORMAL)).is_equal(0)

func test_unique_individual_hardcore_modifier_plus_one():
	assert_that(DifficultyModifiers.get_unique_individual_roll_modifier(
		GlobalEnumsRef.DifficultyLevel.HARDCORE)).is_equal(1)

func test_unique_individual_not_forced_hardcore():
	assert_that(DifficultyModifiers.is_unique_individual_forced(
		GlobalEnumsRef.DifficultyLevel.HARDCORE)).is_false()

func test_unique_individual_forced_insanity():
	assert_that(DifficultyModifiers.is_unique_individual_forced(
		GlobalEnumsRef.DifficultyLevel.INSANITY)).is_true()

func test_double_unique_possible_insanity():
	assert_that(DifficultyModifiers.can_have_double_unique_individual(
		GlobalEnumsRef.DifficultyLevel.INSANITY)).is_true()

func test_double_unique_not_possible_hardcore():
	assert_that(DifficultyModifiers.can_have_double_unique_individual(
		GlobalEnumsRef.DifficultyLevel.HARDCORE)).is_false()

# ============================================================================
# Stars of the Story (INSANITY: disabled)
# ============================================================================

func test_stars_of_story_enabled_normal():
	assert_that(DifficultyModifiers.are_stars_of_story_disabled(
		GlobalEnumsRef.DifficultyLevel.NORMAL)).is_false()

func test_stars_of_story_enabled_hardcore():
	assert_that(DifficultyModifiers.are_stars_of_story_disabled(
		GlobalEnumsRef.DifficultyLevel.HARDCORE)).is_false()

func test_stars_of_story_disabled_insanity():
	assert_that(DifficultyModifiers.are_stars_of_story_disabled(
		GlobalEnumsRef.DifficultyLevel.INSANITY)).is_true()

# ============================================================================
# Comprehensive Modifier Query (get_all_modifiers)
# ============================================================================

func test_all_modifiers_hardcore_complete():
	"""HARDCORE should have all expected modifiers set"""
	var mods = DifficultyModifiers.get_all_modifiers(
		GlobalEnumsRef.DifficultyLevel.HARDCORE)
	assert_that(mods.enemy_count_modifier).is_equal(1)
	assert_that(mods.invasion_roll_modifier).is_equal(2)
	assert_that(mods.seize_initiative_modifier).is_equal(-2)
	assert_that(mods.rival_resistance_modifier).is_equal(-2)
	assert_that(mods.unique_individual_roll_modifier).is_equal(1)
	assert_that(mods.unique_individual_forced).is_false()
	assert_that(mods.story_points_disabled).is_false()
	assert_that(mods.stars_of_story_disabled).is_false()

func test_all_modifiers_insanity_complete():
	"""INSANITY should have all extreme modifiers set"""
	var mods = DifficultyModifiers.get_all_modifiers(
		GlobalEnumsRef.DifficultyLevel.INSANITY)
	assert_that(mods.specialist_enemy_modifier).is_equal(1)
	assert_that(mods.invasion_roll_modifier).is_equal(3)
	assert_that(mods.seize_initiative_modifier).is_equal(-3)
	assert_that(mods.unique_individual_forced).is_true()
	assert_that(mods.double_unique_possible).is_true()
	assert_that(mods.story_points_disabled).is_true()
	assert_that(mods.stars_of_story_disabled).is_true()
