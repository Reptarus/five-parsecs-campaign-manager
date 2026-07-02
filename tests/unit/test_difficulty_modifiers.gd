extends GdUnitTestSuite
## Difficulty Modifiers System Tests (rewritten 2026-07-02)
## Core Rules pp.64-65 — 5 real modes: Easy(1), Normal(2), Challenging(4),
## Hardcore(6), Insanity(8). HARD(3)/NIGHTMARE(5)/ELITE(7) are DEPRECATED
## save-compat aliases (HARD→Normal behavior, NIGHTMARE/ELITE→Insanity).
##
## The original suite encoded a pre-audit enum layout (CHALLENGING=3,
## HARDCORE=4, INSANITY=5) and a nonexistent
## GlobalEnums.get_difficulty_level_name() API with non-book names
## ("Story Mode"/"Standard"/"Nightmare"). All values below come from
## data/difficulty_modifiers.json (Core Rules pp.64-65) via the real
## DifficultyModifiers static API.

const DM = preload("res://src/core/systems/DifficultyModifiers.gd")


# ============================================================================
# Canonical enum values (Core Rules pp.64-65; deprecated aliases persist)
# ============================================================================

func test_difficulty_enum_canonical_values():
	assert_int(GlobalEnums.DifficultyLevel.NONE).is_equal(0)
	assert_int(GlobalEnums.DifficultyLevel.EASY).is_equal(1)
	assert_int(GlobalEnums.DifficultyLevel.NORMAL).is_equal(2)
	assert_int(GlobalEnums.DifficultyLevel.CHALLENGING).is_equal(4)
	assert_int(GlobalEnums.DifficultyLevel.HARDCORE).is_equal(6)
	assert_int(GlobalEnums.DifficultyLevel.INSANITY).is_equal(8)


func test_deprecated_aliases_still_exist_for_save_compat():
	# Never expose in UI; kept only so legacy saves keep loading.
	assert_int(GlobalEnums.DifficultyLevel.HARD).is_equal(3)
	assert_int(GlobalEnums.DifficultyLevel.NIGHTMARE).is_equal(5)
	assert_int(GlobalEnums.DifficultyLevel.ELITE).is_equal(7)


# ============================================================================
# Easy (Core Rules p.64)
# ============================================================================

func test_easy_xp_bonus_is_1():
	assert_int(DM.get_xp_bonus(GlobalEnums.DifficultyLevel.EASY)).is_equal(1)


func test_easy_reduces_enemy_at_5_plus():
	# Easy: remove 1 Basic enemy if total would be 5+ opponents
	assert_int(DM.get_easy_enemy_reduction(5, GlobalEnums.DifficultyLevel.EASY)) \
		.is_equal(1)
	assert_int(DM.get_easy_enemy_reduction(4, GlobalEnums.DifficultyLevel.EASY)) \
		.is_equal(0)


# ============================================================================
# Normal (Core Rules p.65) — rules as written, no modifiers
# ============================================================================

func test_normal_has_no_modifiers():
	var d := GlobalEnums.DifficultyLevel.NORMAL as int
	assert_int(DM.get_xp_bonus(d)).is_equal(0)
	assert_int(DM.get_enemy_count_modifier(d)).is_equal(0)
	assert_bool(DM.should_reroll_low_enemy_dice(d)).is_false()
	assert_bool(DM.are_story_points_disabled(d)).is_false()


# ============================================================================
# Challenging (Core Rules p.65)
# ============================================================================

func test_challenging_rerolls_low_enemy_dice():
	assert_bool(DM.should_reroll_low_enemy_dice(
		GlobalEnums.DifficultyLevel.CHALLENGING)).is_true()


func test_deprecated_hard_does_not_reroll():
	# HARD(3) aliases to NORMAL behavior, not Challenging
	assert_bool(DM.should_reroll_low_enemy_dice(
		GlobalEnums.DifficultyLevel.HARD)).is_false()


# ============================================================================
# Hardcore (Core Rules p.65)
# ============================================================================

func test_hardcore_enemy_count_modifier_is_1():
	assert_int(DM.get_enemy_count_modifier(
		GlobalEnums.DifficultyLevel.HARDCORE)).is_equal(1)


func test_hardcore_reduces_starting_story_points_by_1():
	assert_int(DM.get_starting_story_points_modifier(
		GlobalEnums.DifficultyLevel.HARDCORE)).is_equal(-1)


func test_hardcore_seize_initiative_minus_2():
	assert_int(DM.get_seize_initiative_modifier(
		GlobalEnums.DifficultyLevel.HARDCORE)).is_equal(-2)


# ============================================================================
# Insanity (Core Rules p.65)
# ============================================================================

func test_insanity_disables_story_points():
	assert_bool(DM.are_story_points_disabled(
		GlobalEnums.DifficultyLevel.INSANITY)).is_true()


func test_insanity_adds_specialist_enemy():
	assert_int(DM.get_specialist_enemy_modifier(
		GlobalEnums.DifficultyLevel.INSANITY)).is_equal(1)


func test_insanity_seize_initiative_minus_3():
	assert_int(DM.get_seize_initiative_modifier(
		GlobalEnums.DifficultyLevel.INSANITY)).is_equal(-3)


func test_deprecated_nightmare_and_elite_alias_to_insanity_behavior():
	# Legacy saves on NIGHTMARE/ELITE must keep Insanity semantics
	assert_bool(DM.are_story_points_disabled(
		GlobalEnums.DifficultyLevel.NIGHTMARE)).is_true()
	assert_bool(DM.are_story_points_disabled(
		GlobalEnums.DifficultyLevel.ELITE)).is_true()


# ============================================================================
# Validation
# ============================================================================

func test_all_canonical_levels_are_valid():
	for d in [GlobalEnums.DifficultyLevel.EASY, GlobalEnums.DifficultyLevel.NORMAL,
			GlobalEnums.DifficultyLevel.CHALLENGING,
			GlobalEnums.DifficultyLevel.HARDCORE,
			GlobalEnums.DifficultyLevel.INSANITY]:
		assert_bool(DM.is_valid_difficulty(d)).is_true()
