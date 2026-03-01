extends GdUnitTestSuite
## Phase 4B-5C: Loot System Tests - Part 2: Main Loot Table
## Tests main loot table and subtable integration (Five Parsecs rulebook p.7084-7280)
## gdUnit4 v6.0.1 compatible

# System under test
var HelperClass
var helper

func before():
	"""Suite-level setup - runs once before all tests"""
	HelperClass = load("res://tests/helpers/LootSystemHelper.gd")
	helper = HelperClass.new()

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	HelperClass = null

# ============================================================================
# _roll_loot_table() Tests - Weapon Range (2 tests)
# ============================================================================

func test_loot_table_weapon_minimum():
	"""Roll 1 results in single weapon"""
	var result = helper._roll_loot_table(1, 20)  # Force slug weapon

	assert_that(result.category).is_equal("Weapon")
	assert_that(result.item).is_not_empty()
	assert_that(result.requires_repair).is_false()
	assert_that(result.credits).is_equal(0)

func test_loot_table_weapon_maximum():
	"""Roll 25 results in single weapon"""
	var result = helper._roll_loot_table(25, 50)  # Force energy weapon

	assert_that(result.category).is_equal("Weapon")
	assert_that(result.requires_repair).is_false()

# ============================================================================
# _roll_loot_table() Tests - Damaged Weapons Range (2 tests)
# ============================================================================

func test_loot_table_damaged_weapons_minimum():
	"""Roll 26 results in 2 damaged weapons"""
	var result = helper._roll_loot_table(26, 20, 50)  # Two different weapon types

	assert_that(result.category).is_equal("Damaged Weapons")
	assert_that(result.item).contains("damaged")
	assert_that(result.requires_repair).is_true()
	assert_that(result.credits).is_equal(0)

func test_loot_table_damaged_weapons_maximum():
	"""Roll 35 results in 2 damaged weapons"""
	var result = helper._roll_loot_table(35, 70, 90)  # Force melee + grenades

	assert_that(result.category).is_equal("Damaged Weapons")
	assert_that(result.requires_repair).is_true()

# ============================================================================
# _roll_loot_table() Tests - Damaged Gear Range (2 tests)
# ============================================================================

func test_loot_table_damaged_gear_minimum():
	"""Roll 36 results in 2 damaged gear items"""
	var result = helper._roll_loot_table(36, 0, 0, 10, 50)  # Gun mod + protective item

	assert_that(result.category).is_equal("Damaged Gear")
	assert_that(result.item).contains("damaged")
	assert_that(result.requires_repair).is_true()
	assert_that(result.credits).is_equal(0)

func test_loot_table_damaged_gear_maximum():
	"""Roll 45 results in 2 damaged gear items"""
	var result = helper._roll_loot_table(45, 0, 0, 30, 80)  # Gun sight + utility item

	assert_that(result.category).is_equal("Damaged Gear")
	assert_that(result.requires_repair).is_true()

# ============================================================================
# _roll_loot_table() Tests - Gear Range (2 tests)
# ============================================================================

func test_loot_table_gear_minimum():
	"""Roll 46 results in single gear item"""
	var result = helper._roll_loot_table(46, 0, 0, 15)  # Gun mod

	assert_that(result.category).is_equal("Gear")
	assert_that(result.item).is_not_empty()
	assert_that(result.requires_repair).is_false()
	assert_that(result.credits).is_equal(0)

func test_loot_table_gear_maximum():
	"""Roll 65 results in single gear item"""
	var result = helper._roll_loot_table(65, 0, 0, 60)  # Protective item

	assert_that(result.category).is_equal("Gear")
	assert_that(result.requires_repair).is_false()

# ============================================================================
# _roll_loot_table() Tests - Odds and Ends Range (2 tests)
# ============================================================================

func test_loot_table_odds_and_ends_minimum():
	"""Roll 66 results in odds and ends item"""
	var result = helper._roll_loot_table(66, 0, 0, 0, 0, 30)  # Consumable

	assert_that(result.category).is_equal("Odds and Ends")
	assert_that(result.item).is_not_empty()
	assert_that(result.credits).is_equal(0)

func test_loot_table_odds_and_ends_maximum():
	"""Roll 80 results in odds and ends item"""
	var result = helper._roll_loot_table(80, 0, 0, 0, 0, 90)  # Ship item

	assert_that(result.category).is_equal("Odds and Ends")
	assert_that(result.item).is_not_empty()

# ============================================================================
# _roll_loot_table() Tests - Rewards Range (3 tests)
# ============================================================================

func test_loot_table_rewards_minimum():
	"""Roll 81 results in reward (may have credits or rumors)"""
	var result = helper._roll_loot_table(81, 0, 0, 0, 0, 0, 5)  # Documents reward

	assert_that(result.category).is_equal("Rewards")
	assert_that(result.item).is_not_empty()

func test_loot_table_rewards_maximum():
	"""Roll 100 results in reward"""
	var result = helper._roll_loot_table(100, 0, 0, 0, 0, 0, 100)  # Personal item

	assert_that(result.category).is_equal("Rewards")
	assert_that(result.item).is_not_empty()

func test_loot_table_rewards_with_credits():
	"""Rewards can include credit values"""
	var result = helper._roll_loot_table(85, 0, 0, 0, 0, 0, 25)  # Scrap = 3 credits

	assert_that(result.category).is_equal("Rewards")
	# Credits or rumors should be > 0 for most reward types
	var has_value = result.credits > 0 or result.rumors > 0
	assert_that(has_value).is_true()
