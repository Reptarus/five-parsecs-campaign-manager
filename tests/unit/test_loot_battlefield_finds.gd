extends GdUnitTestSuite
## Phase 4B-5C: Loot System Tests - Part 1: Battlefield Finds
## Tests battlefield finds table lookups (Five Parsecs rulebook p.6601-6670)
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
# _roll_battlefield_finds() Tests - Weapon Range (2 tests)
# ============================================================================

func test_battlefield_finds_weapon_minimum():
	"""Roll 1 results in weapon from slain enemy"""
	var result = helper._roll_battlefield_finds(1, 0)

	assert_that(result.category).is_equal("Weapon")
	assert_that(result.description).contains("weapon")
	assert_that(result.quest_rumor).is_false()
	assert_that(result.credits).is_equal(0)

func test_battlefield_finds_weapon_maximum():
	"""Roll 15 results in weapon from slain enemy"""
	var result = helper._roll_battlefield_finds(15, 0)

	assert_that(result.category).is_equal("Weapon")
	assert_that(result.description).contains("weapon")

# ============================================================================
# _roll_battlefield_finds() Tests - Consumable Range (1 test)
# ============================================================================

func test_battlefield_finds_consumable():
	"""Roll 20 results in consumable item"""
	var result = helper._roll_battlefield_finds(20, 0)

	assert_that(result.category).is_equal("Consumable")
	assert_that(result.description).contains("consumable")
	assert_that(result.credits).is_equal(0)

# ============================================================================
# _roll_battlefield_finds() Tests - Quest Rumor Range (2 tests)
# ============================================================================

func test_battlefield_finds_quest_rumor_minimum():
	"""Roll 26 results in quest rumor with flag set"""
	var result = helper._roll_battlefield_finds(26, 0)

	assert_that(result.category).is_equal("Quest Rumor")
	assert_that(result.quest_rumor).is_true()
	assert_that(result.description).contains("data stick")
	assert_that(result.credits).is_equal(0)

func test_battlefield_finds_quest_rumor_maximum():
	"""Roll 35 results in quest rumor"""
	var result = helper._roll_battlefield_finds(35, 0)

	assert_that(result.category).is_equal("Quest Rumor")
	assert_that(result.quest_rumor).is_true()

# ============================================================================
# _roll_battlefield_finds() Tests - Ship Part Range (1 test)
# ============================================================================

func test_battlefield_finds_ship_part():
	"""Roll 40 results in ship part worth 2 credits"""
	var result = helper._roll_battlefield_finds(40, 0)

	assert_that(result.category).is_equal("Ship Part")
	assert_that(result.credits).is_equal(2)
	assert_that(result.description).contains("2 credits")

# ============================================================================
# _roll_battlefield_finds() Tests - Trinket Range (1 test)
# ============================================================================

func test_battlefield_finds_trinket():
	"""Roll 50 results in personal trinket"""
	var result = helper._roll_battlefield_finds(50, 0)

	assert_that(result.category).is_equal("Trinket")
	assert_that(result.description).contains("trinket")
	assert_that(result.credits).is_equal(0)

# ============================================================================
# _roll_battlefield_finds() Tests - Debris Range (2 tests)
# ============================================================================

func test_battlefield_finds_debris_minimum():
	"""Roll 61 with d6=3 results in 1 credit debris (1D3 minimum)"""
	var result = helper._roll_battlefield_finds(61, 3)

	assert_that(result.category).is_equal("Debris")
	assert_that(result.credits).is_equal(1)  # (3 % 3) + 1 = 1
	assert_that(result.description).contains("Debris")

func test_battlefield_finds_debris_maximum():
	"""Roll 75 with d6=2 results in 3 credit debris (1D3 maximum)"""
	var result = helper._roll_battlefield_finds(75, 2)

	assert_that(result.category).is_equal("Debris")
	assert_that(result.credits).is_equal(3)  # (2 % 3) + 1 = 3
	assert_that(result.description).contains("credits")

# ============================================================================
# _roll_battlefield_finds() Tests - Vital Info & Nothing (2 tests)
# ============================================================================

func test_battlefield_finds_vital_info():
	"""Roll 80 results in vital info for patron"""
	var result = helper._roll_battlefield_finds(80, 0)

	assert_that(result.category).is_equal("Vital Info")
	assert_that(result.description).contains("Vital info")
	assert_that(result.credits).is_equal(0)

func test_battlefield_finds_nothing():
	"""Roll 95 results in nothing of value"""
	var result = helper._roll_battlefield_finds(95, 0)

	assert_that(result.category).is_equal("Nothing")
	assert_that(result.description).contains("Nothing")
	assert_that(result.credits).is_equal(0)
