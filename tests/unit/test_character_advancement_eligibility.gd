extends GdUnitTestSuite
## Phase 4B-5A: Character Advancement System Tests - Part 2: Special Cases and Eligibility
## Tests special stat maximums and advancement eligibility checks
## gdUnit4 v6.0.1 compatible

# Test data
var test_character: Dictionary

# System under test
var HelperClass
var helper

func before():
	"""Suite-level setup - runs once before all tests"""
	HelperClass = load("res://tests/helpers/CharacterAdvancementHelper.gd")
	# Create helper once for entire suite
	helper = HelperClass.new()

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	HelperClass = null

func before_test():
	"""Test-level setup - runs before EACH test"""
	# Reset test data for each test
	test_character = {
		"character_name": "Test Character",
		"experience": 20,
		"reactions": 1,
		"combat_skill": 2,
		"speed": 5,
		"savvy": 1,
		"toughness": 4,
		"luck": 1,
		"background": "Soldier",
		"species": "Human"
	}

func after_test():
	"""Test-level cleanup - runs after EACH test"""
	test_character = {}

# ============================================================================
# _get_stat_maximum() Tests - Special Cases (4 tests)
# ============================================================================

func test_get_stat_maximum_luck_human_returns_3():
	"""Humans can reach Luck 3"""
	test_character["species"] = "Human"
	var max_value = helper._get_stat_maximum("luck", test_character)
	assert_that(max_value).is_equal(3)

func test_get_stat_maximum_luck_non_human_returns_1():
	"""Non-human species max Luck at 1"""
	test_character["species"] = "K'Erin"
	var max_value = helper._get_stat_maximum("luck", test_character)
	assert_that(max_value).is_equal(1)

func test_get_stat_maximum_case_insensitive():
	"""Stat names are case-insensitive"""
	var max_lower = helper._get_stat_maximum("reactions", test_character)
	var max_upper = helper._get_stat_maximum("REACTIONS", test_character)
	var max_mixed = helper._get_stat_maximum("Reactions", test_character)

	assert_that(max_lower).is_equal(6)
	assert_that(max_upper).is_equal(6)
	assert_that(max_mixed).is_equal(6)

func test_get_stat_maximum_invalid_stat_returns_10():
	"""Invalid stat names return 10 as default maximum"""
	var max_value = helper._get_stat_maximum("invalid_stat", test_character)
	assert_that(max_value).is_equal(10)

# ============================================================================
# _can_character_advance() Tests (8 tests)
# ============================================================================

func test_can_character_advance_with_sufficient_xp():
	"""Character with 20 XP can advance stats costing ≤20 XP"""
	test_character["experience"] = 20
	test_character["combat_skill"] = 2  # Not at max (5)
	test_character["reactions"] = 1  # Not at max (6)
	test_character["speed"] = 5  # Not at max (8)

	var available = helper._can_character_advance(test_character)

	assert_that(available).is_not_empty()
	# Should include stats costing 5-7 XP: combat_skill(7), reactions(7), speed(5), savvy(5), toughness(6)
	assert_that(available).contains(["combat_skill", "reactions", "speed"])

func test_can_character_advance_insufficient_xp_returns_empty():
	"""Character with insufficient XP cannot advance anything"""
	test_character["experience"] = 3  # Less than cheapest advancement (5 XP)

	var available = helper._can_character_advance(test_character)

	assert_that(available).is_empty()

func test_can_character_advance_at_maximum_excluded():
	"""Stats already at maximum are excluded from available advancements"""
	test_character["experience"] = 100
	test_character["combat_skill"] = 5  # At maximum
	test_character["reactions"] = 6  # At maximum

	var available = helper._can_character_advance(test_character)

	assert_that(available).not_contains(["combat_skill", "reactions"])

func test_can_character_advance_engineer_toughness_cap():
	"""Engineers cannot advance Toughness beyond 4"""
	test_character["background"] = "Engineer"
	test_character["experience"] = 100
	test_character["toughness"] = 4  # At Engineer maximum

	var available = helper._can_character_advance(test_character)

	assert_that(available).not_contains(["toughness"])

func test_can_character_advance_human_luck_exception():
	"""Humans can advance Luck to 3, non-humans only to 1"""
	var human = test_character.duplicate()
	human["species"] = "Human"
	human["experience"] = 30
	human["luck"] = 1

	var human_available = helper._can_character_advance(human)
	assert_that(human_available).contains(["luck"])

	var alien = test_character.duplicate()
	alien["species"] = "K'Erin"
	alien["experience"] = 30
	alien["luck"] = 1  # Already at alien maximum

	var alien_available = helper._can_character_advance(alien)
	assert_that(alien_available).not_contains(["luck"])

func test_can_character_advance_returns_array():
	"""Returns an Array type"""
	var available = helper._can_character_advance(test_character)

	assert_that(available).is_not_null()
	# Note: Array type checking in gdUnit4
	assert_that(typeof(available)).is_equal(TYPE_ARRAY)

func test_can_character_advance_zero_xp():
	"""Character with 0 XP cannot advance"""
	test_character["experience"] = 0

	var available = helper._can_character_advance(test_character)

	assert_that(available).is_empty()

func test_can_character_advance_multiple_stats_available():
	"""Character can have multiple stats available for advancement"""
	test_character["experience"] = 50  # Enough for all stats
	test_character["reactions"] = 1  # Can advance
	test_character["combat_skill"] = 2  # Can advance
	test_character["speed"] = 5  # Can advance
	test_character["savvy"] = 1  # Can advance
	test_character["toughness"] = 4  # Can advance
	test_character["luck"] = 1  # Can advance (human)

	var available = helper._can_character_advance(test_character)

	# Should have 6 stats available
	assert_that(available).has_size(6)
