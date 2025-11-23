extends GdUnitTestSuite
## Phase 4B-5C: Loot System Tests - Part 4: Rewards Subtable
## Tests rewards subtable with credits and rumors (Five Parsecs rulebook p.7250-7280)
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
# _roll_rewards_subtable() Tests - Rumors (2 tests)
# ============================================================================

func test_rewards_documents():
	"""Roll 5 results in documents with 1 quest rumor"""
	var result = helper._roll_rewards_subtable(5, 0, 0)

	assert_that(result.item).is_equal("Documents")
	assert_that(result.rumors).is_equal(1)
	assert_that(result.credits).is_equal(0)

func test_rewards_data_files():
	"""Roll 15 results in data files with 2 quest rumors"""
	var result = helper._roll_rewards_subtable(15, 0, 0)

	assert_that(result.item).is_equal("Data Files")
	assert_that(result.rumors).is_equal(2)
	assert_that(result.credits).is_equal(0)

# ============================================================================
# _roll_rewards_subtable() Tests - Fixed Credits (1 test)
# ============================================================================

func test_rewards_scrap():
	"""Roll 23 results in scrap worth 3 credits"""
	var result = helper._roll_rewards_subtable(23, 0, 0)

	assert_that(result.item).is_equal("Scrap")
	assert_that(result.credits).is_equal(3)
	assert_that(result.rumors).is_equal(0)

# ============================================================================
# _roll_rewards_subtable() Tests - Variable Credits (4 tests)
# ============================================================================

func test_rewards_cargo_crate_minimum():
	"""Roll 30 with d6=1 results in cargo crate worth 1 credit"""
	var result = helper._roll_rewards_subtable(30, 1, 0)

	assert_that(result.item).is_equal("Cargo Crate")
	assert_that(result.credits).is_equal(1)

func test_rewards_cargo_crate_maximum():
	"""Roll 40 with d6=6 results in cargo crate worth 6 credits"""
	var result = helper._roll_rewards_subtable(40, 6, 0)

	assert_that(result.item).is_equal("Cargo Crate")
	assert_that(result.credits).is_equal(6)

func test_rewards_valuable_materials():
	"""Roll 50 with d6=3 results in valuable materials worth 5 credits (3+2)"""
	var result = helper._roll_rewards_subtable(50, 3, 0)

	assert_that(result.item).is_equal("Valuable Materials")
	assert_that(result.credits).is_equal(5)  # d6 + 2

func test_rewards_rare_substance_pick_highest():
	"""Roll 65 with d6_1=2, d6_2=5 picks highest die (5 credits)"""
	var result = helper._roll_rewards_subtable(65, 2, 5)

	assert_that(result.item).is_equal("Rare Substance")
	assert_that(result.credits).is_equal(5)  # max(2, 5)

# ============================================================================
# _roll_rewards_subtable() Tests - Ship Components (2 tests)
# ============================================================================

func test_rewards_ship_parts_discount():
	"""Roll 75 with d6=4 results in 4 credit ship component discount"""
	var result = helper._roll_rewards_subtable(75, 4, 0)

	assert_that(result.item).contains("Ship Parts")
	assert_that(result.item).contains("4 credits")
	assert_that(result.item).contains("discount")

func test_rewards_military_ship_part_discount():
	"""Roll 88 with d6=3 results in 5 credit discount (3+2)"""
	var result = helper._roll_rewards_subtable(88, 3, 0)

	assert_that(result.item).contains("Military Ship Part")
	assert_that(result.item).contains("5 credits")  # d6 + 2
	assert_that(result.item).contains("discount")

# ============================================================================
# _roll_rewards_subtable() Tests - Story Points (2 tests)
# ============================================================================

func test_rewards_mysterious_items():
	"""Roll 92 results in mysterious items worth story points"""
	var result = helper._roll_rewards_subtable(92, 0, 0)

	assert_that(result.item).contains("Mysterious Items")
	assert_that(result.item).contains("story points")

func test_rewards_personal_item():
	"""Roll 98 results in personal item worth story points"""
	var result = helper._roll_rewards_subtable(98, 0, 0)

	assert_that(result.item).contains("Personal Item")
	assert_that(result.item).contains("story points")
