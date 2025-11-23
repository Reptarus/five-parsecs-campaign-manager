extends GdUnitTestSuite
## Phase 4B-5A: Character Advancement System Tests - Part 1: Costs and Basic Maximums
## Tests XP costs and basic stat maximum validation
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
# _get_character_advancement_cost() Tests (7 tests)
# ============================================================================

func test_get_advancement_cost_reactions_returns_7():
	"""Reactions advancement costs 7 XP"""
	var cost = helper._get_character_advancement_cost("reactions")
	assert_that(cost).is_equal(7)

func test_get_advancement_cost_combat_skill_returns_7():
	"""Combat skill advancement costs 7 XP"""
	var cost = helper._get_character_advancement_cost("combat_skill")
	assert_that(cost).is_equal(7)

func test_get_advancement_cost_speed_returns_5():
	"""Speed advancement costs 5 XP"""
	var cost = helper._get_character_advancement_cost("speed")
	assert_that(cost).is_equal(5)

func test_get_advancement_cost_savvy_returns_5():
	"""Savvy advancement costs 5 XP"""
	var cost = helper._get_character_advancement_cost("savvy")
	assert_that(cost).is_equal(5)

func test_get_advancement_cost_toughness_returns_6():
	"""Toughness advancement costs 6 XP"""
	var cost = helper._get_character_advancement_cost("toughness")
	assert_that(cost).is_equal(6)

func test_get_advancement_cost_luck_returns_10():
	"""Luck advancement costs 10 XP (most expensive)"""
	var cost = helper._get_character_advancement_cost("luck")
	assert_that(cost).is_equal(10)

func test_get_advancement_cost_invalid_stat_returns_999():
	"""Invalid stat names return 999 as safety value"""
	var cost = helper._get_character_advancement_cost("invalid_stat")
	assert_that(cost).is_equal(999)

# ============================================================================
# _get_stat_maximum() Tests - Basic Stats (6 tests)
# ============================================================================

func test_get_stat_maximum_reactions_returns_6():
	"""Reactions maximum is 6 for all characters"""
	var max_value = helper._get_stat_maximum("reactions", test_character)
	assert_that(max_value).is_equal(6)

func test_get_stat_maximum_combat_skill_returns_5():
	"""Combat skill maximum is 5 for all characters"""
	var max_value = helper._get_stat_maximum("combat_skill", test_character)
	assert_that(max_value).is_equal(5)

func test_get_stat_maximum_speed_returns_8():
	"""Speed maximum is 8 for all characters"""
	var max_value = helper._get_stat_maximum("speed", test_character)
	assert_that(max_value).is_equal(8)

func test_get_stat_maximum_savvy_returns_5():
	"""Savvy maximum is 5 for all characters"""
	var max_value = helper._get_stat_maximum("savvy", test_character)
	assert_that(max_value).is_equal(5)

func test_get_stat_maximum_toughness_normal_returns_6():
	"""Toughness maximum is 6 for non-Engineer characters"""
	test_character["background"] = "Soldier"
	var max_value = helper._get_stat_maximum("toughness", test_character)
	assert_that(max_value).is_equal(6)

func test_get_stat_maximum_toughness_engineer_returns_4():
	"""Engineers have restricted Toughness maximum of 4"""
	test_character["background"] = "Engineer"
	var max_value = helper._get_stat_maximum("toughness", test_character)
	assert_that(max_value).is_equal(4)
