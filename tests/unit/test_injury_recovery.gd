extends GdUnitTestSuite
## Phase 4B-5B: Injury System Tests - Part 2: Minor Injuries and Recovery
## Tests minor injury outcomes and sick bay recovery mechanics
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
# _determine_injury() Tests - Minor Injury (3 tests)
# ============================================================================

func test_determine_injury_minor_minimum():
	"""Roll 55 results in minor injury (1 turn)"""
	var injury = helper._determine_injury(55)

	assert_that(injury.description).contains("MINOR")
	assert_that(injury.recovery_turns).is_equal(1)
	assert_that(injury.requires_surgery).is_false()

func test_determine_injury_minor_mid_range():
	"""Roll 67 results in minor injury"""
	var injury = helper._determine_injury(67)

	assert_that(injury.recovery_turns).is_equal(1)

func test_determine_injury_minor_maximum():
	"""Roll 80 results in minor injury"""
	var injury = helper._determine_injury(80)

	assert_that(injury.recovery_turns).is_equal(1)

# ============================================================================
# _determine_injury() Tests - Knocked Out (3 tests)
# ============================================================================

func test_determine_injury_knocked_out_minimum():
	"""Roll 81 results in knocked out (no sick bay)"""
	var injury = helper._determine_injury(81)

	assert_that(injury.description).contains("KNOCKED OUT")
	assert_that(injury.recovery_turns).is_equal(0)
	assert_that(injury.is_fatal).is_false()

func test_determine_injury_knocked_out_mid_range():
	"""Roll 88 results in knocked out"""
	var injury = helper._determine_injury(88)

	assert_that(injury.recovery_turns).is_equal(0)

func test_determine_injury_knocked_out_maximum():
	"""Roll 95 results in knocked out"""
	var injury = helper._determine_injury(95)

	assert_that(injury.recovery_turns).is_equal(0)

# ============================================================================
# _determine_injury() Tests - School of Hard Knocks (3 tests)
# ============================================================================

func test_determine_injury_hard_knocks_minimum():
	"""Roll 96 results in bonus XP gain"""
	var injury = helper._determine_injury(96)

	assert_that(injury.description).contains("Hard Knocks")
	assert_that(injury.bonus_xp).is_equal(1)
	assert_that(injury.recovery_turns).is_equal(0)
	assert_that(injury.is_fatal).is_false()

func test_determine_injury_hard_knocks_mid_range():
	"""Roll 98 results in bonus XP gain"""
	var injury = helper._determine_injury(98)

	assert_that(injury.bonus_xp).is_equal(1)

func test_determine_injury_hard_knocks_maximum():
	"""Roll 100 results in bonus XP gain"""
	var injury = helper._determine_injury(100)

	assert_that(injury.bonus_xp).is_equal(1)

# ============================================================================
# _process_injury_recovery() Tests (6 tests)
# ============================================================================

func test_process_recovery_empty_sick_bay():
	"""Empty injured list returns empty results"""
	var injured = []
	var results = helper._process_injury_recovery(injured)

	assert_that(results.total_in_sick_bay).is_equal(0)
	assert_that(results.recovered).is_empty()
	assert_that(results.still_injured).is_empty()
	assert_that(injured).is_empty()

func test_process_recovery_single_character_recovers():
	"""Character with 1 turn remaining recovers"""
	var injured = [
		{"name": "Test Character", "turns_remaining": 1, "requires_surgery": false}
	]
	var results = helper._process_injury_recovery(injured)

	assert_that(results.total_in_sick_bay).is_equal(1)
	assert_that(results.recovered).contains(["Test Character"])
	assert_that(results.still_injured).is_empty()
	assert_that(injured).is_empty()  # Character removed from sick bay

func test_process_recovery_character_still_injured():
	"""Character with multiple turns remaining stays in sick bay"""
	var injured = [
		{"name": "Test Character", "turns_remaining": 3, "requires_surgery": false}
	]
	var results = helper._process_injury_recovery(injured)

	assert_that(results.recovered).is_empty()
	assert_that(results.still_injured).has_size(1)
	assert_that(results.still_injured[0].name).is_equal("Test Character")
	assert_that(results.still_injured[0].turns_remaining).is_equal(2)  # Decremented
	assert_that(injured).has_size(1)  # Still in sick bay
	assert_that(injured[0].turns_remaining).is_equal(2)

func test_process_recovery_with_surgery_flag():
	"""Surgery flag is preserved during recovery"""
	var injured = [
		{"name": "Crippled Character", "turns_remaining": 2, "requires_surgery": true}
	]
	var results = helper._process_injury_recovery(injured)

	assert_that(results.still_injured[0].requires_surgery).is_true()
	assert_that(injured[0].requires_surgery).is_true()

func test_process_recovery_multiple_characters_mixed_states():
	"""Multiple characters with different recovery states"""
	var injured = [
		{"name": "Recovering Soon", "turns_remaining": 1, "requires_surgery": false},
		{"name": "Long Recovery", "turns_remaining": 5, "requires_surgery": true},
		{"name": "Almost There", "turns_remaining": 2, "requires_surgery": false}
	]
	var results = helper._process_injury_recovery(injured)

	assert_that(results.total_in_sick_bay).is_equal(3)
	assert_that(results.recovered).has_size(1)
	assert_that(results.recovered).contains(["Recovering Soon"])
	assert_that(results.still_injured).has_size(2)
	assert_that(injured).has_size(2)  # One character removed

func test_process_recovery_decrements_all_turns():
	"""All injured characters have turns decremented"""
	var injured = [
		{"name": "Character A", "turns_remaining": 4, "requires_surgery": false},
		{"name": "Character B", "turns_remaining": 2, "requires_surgery": false},
		{"name": "Character C", "turns_remaining": 3, "requires_surgery": true}
	]
	helper._process_injury_recovery(injured)

	# All should be decremented by 1
	assert_that(injured[0].turns_remaining).is_equal(3)
	assert_that(injured[1].turns_remaining).is_equal(1)
	assert_that(injured[2].turns_remaining).is_equal(2)
