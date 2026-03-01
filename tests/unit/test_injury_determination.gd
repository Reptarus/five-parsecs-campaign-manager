extends GdUnitTestSuite
## Phase 4B-5B: Injury System Tests - Part 1: Injury Determination
## Tests injury table lookups for D100 rolls
## gdUnit4 v6.0.1 compatible

# System under test
var HelperClass
var helper

func before():
	"""Suite-level setup - runs once before all tests"""
	HelperClass = load("res://tests/helpers/InjurySystemHelper.gd")
	helper = HelperClass.new()

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	HelperClass = null

# ============================================================================
# _determine_injury() Tests - Fatal Range (3 tests)
# ============================================================================

func test_determine_injury_fatal_minimum():
	"""Roll 1 results in fatal injury"""
	var injury = helper._determine_injury(1)

	assert_that(injury.is_fatal).is_true()
	assert_that(injury.description).contains("DEAD")
	assert_that(injury.recovery_turns).is_equal(0)
	assert_that(injury.requires_surgery).is_false()

func test_determine_injury_fatal_mid_range():
	"""Roll 8 results in fatal injury"""
	var injury = helper._determine_injury(8)

	assert_that(injury.is_fatal).is_true()
	assert_that(injury.description).contains("DEAD")

func test_determine_injury_fatal_maximum():
	"""Roll 15 results in fatal injury"""
	var injury = helper._determine_injury(15)

	assert_that(injury.is_fatal).is_true()
	assert_that(injury.description).contains("DEAD")

# ============================================================================
# _determine_injury() Tests - Miraculous Escape (1 test)
# ============================================================================

func test_determine_injury_miraculous_escape():
	"""Roll 16 results in miraculous escape with no injury"""
	var injury = helper._determine_injury(16)

	assert_that(injury.is_fatal).is_false()
	assert_that(injury.description).contains("Miraculous")
	assert_that(injury.recovery_turns).is_equal(0)
	assert_that(injury.equipment_lost).is_false()

# ============================================================================
# _determine_injury() Tests - Equipment Loss (3 tests)
# ============================================================================

func test_determine_injury_equipment_loss_minimum():
	"""Roll 17 results in equipment loss"""
	var injury = helper._determine_injury(17)

	assert_that(injury.equipment_lost).is_true()
	assert_that(injury.description).contains("Equipment")
	assert_that(injury.recovery_turns).is_equal(0)
	assert_that(injury.is_fatal).is_false()

func test_determine_injury_equipment_loss_mid_range():
	"""Roll 23 results in equipment loss"""
	var injury = helper._determine_injury(23)

	assert_that(injury.equipment_lost).is_true()
	assert_that(injury.recovery_turns).is_equal(0)

func test_determine_injury_equipment_loss_maximum():
	"""Roll 30 results in equipment loss"""
	var injury = helper._determine_injury(30)

	assert_that(injury.equipment_lost).is_true()
	assert_that(injury.recovery_turns).is_equal(0)

# ============================================================================
# _determine_injury() Tests - Crippling Wound (3 tests)
# ============================================================================

func test_determine_injury_crippling_minimum():
	"""Roll 31 results in crippling wound requiring surgery"""
	var injury = helper._determine_injury(31, 5)  # Pass fixed recovery turns for testing

	assert_that(injury.description).contains("CRIPPLING")
	assert_that(injury.requires_surgery).is_true()
	assert_that(injury.recovery_turns).is_equal(5)
	assert_that(injury.is_fatal).is_false()

func test_determine_injury_crippling_mid_range():
	"""Roll 38 results in crippling wound"""
	var injury = helper._determine_injury(38, 3)

	assert_that(injury.requires_surgery).is_true()
	assert_that(injury.recovery_turns).is_equal(3)

func test_determine_injury_crippling_maximum():
	"""Roll 45 results in crippling wound"""
	var injury = helper._determine_injury(45, 6)

	assert_that(injury.requires_surgery).is_true()
	assert_that(injury.recovery_turns).is_equal(6)

# ============================================================================
# _determine_injury() Tests - Serious Injury (3 tests)
# ============================================================================

func test_determine_injury_serious_minimum():
	"""Roll 46 results in serious injury (1D3+1 turns)"""
	var injury = helper._determine_injury(46, 0, 1)  # 1D3 result = 1, +1 = 2 turns

	assert_that(injury.description).contains("SERIOUS")
	assert_that(injury.recovery_turns).is_equal(2)
	assert_that(injury.requires_surgery).is_false()
	assert_that(injury.is_fatal).is_false()

func test_determine_injury_serious_mid_range():
	"""Roll 50 results in serious injury"""
	var injury = helper._determine_injury(50, 0, 2)  # 1D3 result = 2, +1 = 3 turns

	assert_that(injury.recovery_turns).is_equal(3)

func test_determine_injury_serious_maximum():
	"""Roll 54 results in serious injury"""
	var injury = helper._determine_injury(54, 0, 3)  # 1D3 result = 3, +1 = 4 turns

	assert_that(injury.recovery_turns).is_equal(4)
