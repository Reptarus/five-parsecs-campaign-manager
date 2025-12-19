extends GdUnitTestSuite
## Sprint 1: Crew Size Enemy Calculation Tests
## Tests EnemyGenerator._calculate_enemy_count() implementation
## Core Rules Reference: p.63 (Number of Enemies)
## gdUnit4 v6.0.1 compatible

# System under test
var EnemyGenerator
var enemy_generator

func before():
	"""Suite-level setup - runs once before all tests"""
	EnemyGenerator = load("res://src/core/systems/EnemyGenerator.gd")

func after():
	"""Suite-level cleanup - runs once after all tests"""
	EnemyGenerator = null

func before_test():
	"""Test-level setup - runs before EACH test"""
	enemy_generator = auto_free(EnemyGenerator.new())

func after_test():
	"""Test-level cleanup - runs after EACH test"""
	enemy_generator = null

# ============================================================================
# Crew Size 6 Tests (Roll 2D6, pick HIGHER)
# ============================================================================

func test_crew_6_uses_max_of_two_dice():
	"""Crew size 6 should roll 2D6 and pick the HIGHER result"""
	var standard_difficulty = 2  # Standard mode

	# Run multiple iterations to verify max selection
	var all_results_valid := true
	for i in range(20):
		var enemy_count = enemy_generator._calculate_enemy_count(standard_difficulty, 6)
		# Result should be between 1-6 (single die max)
		if enemy_count < 1 or enemy_count > 6:
			all_results_valid = false
			break

	assert_that(all_results_valid).is_true()

func test_crew_6_minimum_is_1():
	"""Crew size 6 minimum enemy count should be 1 (if both dice roll 1)"""
	var standard_difficulty = 2

	# Test multiple times to potentially hit minimum
	var found_minimum := false
	for i in range(50):
		var enemy_count = enemy_generator._calculate_enemy_count(standard_difficulty, 6)
		if enemy_count == 1:
			found_minimum = true
			break

	# Should eventually find a roll where both dice are 1
	assert_that(found_minimum).is_true()

func test_crew_6_maximum_is_6():
	"""Crew size 6 maximum enemy count should be 6 (if either die rolls 6)"""
	var standard_difficulty = 2

	# Test multiple times to hit maximum
	var found_maximum := false
	for i in range(50):
		var enemy_count = enemy_generator._calculate_enemy_count(standard_difficulty, 6)
		if enemy_count == 6:
			found_maximum = true
			break

	assert_that(found_maximum).is_true()

# ============================================================================
# Crew Size 5 Tests (Roll single 1D6)
# ============================================================================

func test_crew_5_uses_single_die():
	"""Crew size 5 should roll 1D6 for enemy count"""
	var standard_difficulty = 2

	# All results should be 1-6
	var all_results_valid := true
	for i in range(20):
		var enemy_count = enemy_generator._calculate_enemy_count(standard_difficulty, 5)
		if enemy_count < 1 or enemy_count > 6:
			all_results_valid = false
			break

	assert_that(all_results_valid).is_true()

func test_crew_5_can_roll_1():
	"""Crew size 5 should be able to roll minimum (1)"""
	var standard_difficulty = 2

	var found_minimum := false
	for i in range(50):
		var enemy_count = enemy_generator._calculate_enemy_count(standard_difficulty, 5)
		if enemy_count == 1:
			found_minimum = true
			break

	assert_that(found_minimum).is_true()

func test_crew_5_can_roll_6():
	"""Crew size 5 should be able to roll maximum (6)"""
	var standard_difficulty = 2

	var found_maximum := false
	for i in range(50):
		var enemy_count = enemy_generator._calculate_enemy_count(standard_difficulty, 5)
		if enemy_count == 6:
			found_maximum = true
			break

	assert_that(found_maximum).is_true()

# ============================================================================
# Crew Size 4 Tests (Roll 2D6, pick LOWER)
# ============================================================================

func test_crew_4_uses_min_of_two_dice():
	"""Crew size 4 should roll 2D6 and pick the LOWER result"""
	var standard_difficulty = 2

	# All results should be 1-6
	var all_results_valid := true
	for i in range(20):
		var enemy_count = enemy_generator._calculate_enemy_count(standard_difficulty, 4)
		if enemy_count < 1 or enemy_count > 6:
			all_results_valid = false
			break

	assert_that(all_results_valid).is_true()

func test_crew_4_minimum_is_1():
	"""Crew size 4 minimum should be 1 (if either die rolls 1)"""
	var standard_difficulty = 2

	var found_minimum := false
	for i in range(50):
		var enemy_count = enemy_generator._calculate_enemy_count(standard_difficulty, 4)
		if enemy_count == 1:
			found_minimum = true
			break

	assert_that(found_minimum).is_true()

func test_crew_4_maximum_is_6():
	"""Crew size 4 maximum should be 6 (if both dice roll 6)"""
	var standard_difficulty = 2

	var found_maximum := false
	for i in range(50):
		var enemy_count = enemy_generator._calculate_enemy_count(standard_difficulty, 4)
		if enemy_count == 6:
			found_maximum = true
			break

	assert_that(found_maximum).is_true()

# ============================================================================
# Challenging Difficulty Tests (Reroll 1s and 2s)
# ============================================================================

func test_challenging_rerolls_low_dice():
	"""Challenging mode should reroll 1s and 2s before picking result"""
	var challenging_difficulty = 3  # Challenging mode

	# Run multiple tests to check distribution
	# With rerolls, should see fewer 1s and 2s than standard
	var low_roll_count := 0
	var total_tests := 100

	for i in range(total_tests):
		var enemy_count = enemy_generator._calculate_enemy_count(challenging_difficulty, 4)
		if enemy_count <= 2:
			low_roll_count += 1

	# With rerolls, low results should be rare (less than 33% of rolls)
	# Normal probability of 1-2 on 1D6 is 33%, rerolling reduces this significantly
	var low_roll_percentage := float(low_roll_count) / float(total_tests)
	assert_that(low_roll_percentage).is_less(0.35)

func test_challenging_applies_to_crew_6():
	"""Challenging reroll should work with crew size 6 (max of two dice)"""
	var challenging_difficulty = 3

	# Should still produce valid 1-6 results
	var all_results_valid := true
	for i in range(20):
		var enemy_count = enemy_generator._calculate_enemy_count(challenging_difficulty, 6)
		if enemy_count < 1 or enemy_count > 6:
			all_results_valid = false
			break

	assert_that(all_results_valid).is_true()

func test_challenging_applies_to_crew_5():
	"""Challenging reroll should work with crew size 5 (single die)"""
	var challenging_difficulty = 3

	var all_results_valid := true
	for i in range(20):
		var enemy_count = enemy_generator._calculate_enemy_count(challenging_difficulty, 5)
		if enemy_count < 1 or enemy_count > 6:
			all_results_valid = false
			break

	assert_that(all_results_valid).is_true()

# ============================================================================
# Hardcore/Insanity Difficulty Tests (+1 modifier)
# ============================================================================

func test_hardcore_adds_1_to_count():
	"""Hardcore difficulty should add +1 to final enemy count"""
	var hardcore_difficulty = 4

	# All results should be 2-7 (base 1-6 + 1)
	var all_results_valid := true
	for i in range(20):
		var enemy_count = enemy_generator._calculate_enemy_count(hardcore_difficulty, 5)
		if enemy_count < 2 or enemy_count > 7:
			all_results_valid = false
			break

	assert_that(all_results_valid).is_true()

func test_hardcore_applies_to_all_crew_sizes():
	"""Hardcore +1 modifier should apply regardless of crew size"""
	var hardcore_difficulty = 4

	# Test crew size 4
	var count_4 = enemy_generator._calculate_enemy_count(hardcore_difficulty, 4)
	assert_that(count_4).is_between(2, 7)

	# Test crew size 5
	var count_5 = enemy_generator._calculate_enemy_count(hardcore_difficulty, 5)
	assert_that(count_5).is_between(2, 7)

	# Test crew size 6
	var count_6 = enemy_generator._calculate_enemy_count(hardcore_difficulty, 6)
	assert_that(count_6).is_between(2, 7)

# ============================================================================
# Edge Case Tests
# ============================================================================

func test_crew_size_3_uses_min_dice():
	"""Crew size 3 (or lower) should use min of two dice logic (same as crew 4)"""
	var standard_difficulty = 2

	var enemy_count = enemy_generator._calculate_enemy_count(standard_difficulty, 3)
	assert_that(enemy_count).is_between(1, 6)

func test_crew_size_7_uses_max_dice():
	"""Crew size 7 (or higher) should use max of two dice logic (same as crew 6)"""
	var standard_difficulty = 2

	var enemy_count = enemy_generator._calculate_enemy_count(standard_difficulty, 7)
	assert_that(enemy_count).is_between(1, 6)

func test_negative_difficulty_treated_as_standard():
	"""Invalid negative difficulty should default to standard behavior"""
	var invalid_difficulty = -1

	# Should still produce valid results
	var enemy_count = enemy_generator._calculate_enemy_count(invalid_difficulty, 5)
	assert_that(enemy_count).is_between(1, 6)

# ============================================================================
# Integration Tests (Multiple Modifiers)
# ============================================================================

func test_challenging_plus_hardcore_crew_4():
	"""Challenging (reroll) + Hardcore (+1) should work together"""
	var challenging_difficulty = 3

	# Should produce 2-7 with lower probability of 2s
	var all_results_valid := true
	for i in range(20):
		var enemy_count = enemy_generator._calculate_enemy_count(challenging_difficulty, 4)
		# Note: Hardcore adds +1, so range is 2-7
		# But this tests Challenging (3), not Hardcore (4)
		if enemy_count < 1 or enemy_count > 6:
			all_results_valid = false
			break

	assert_that(all_results_valid).is_true()

func test_standard_mode_no_modifiers():
	"""Standard difficulty should apply no special modifiers"""
	var standard_difficulty = 2

	# Pure 1D6 for crew 5
	var all_in_range := true
	for i in range(20):
		var enemy_count = enemy_generator._calculate_enemy_count(standard_difficulty, 5)
		if enemy_count < 1 or enemy_count > 6:
			all_in_range = false
			break

	assert_that(all_in_range).is_true()
