extends GdUnitTestSuite
## Phase 4B-5A: Character Advancement System Tests - Part 3: Application and Processing
## Tests advancement application and automated processing
## gdUnit4 v6.0.1 compatible

# Test data
var test_character: Dictionary
var test_captain: Dictionary
var test_crew: Array

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

	test_captain = {
		"character_name": "Test Captain",
		"experience": 30,
		"reactions": 2,
		"combat_skill": 3,
		"speed": 6,
		"savvy": 2,
		"toughness": 5,
		"luck": 1,
		"background": "Soldier",
		"species": "Human"
	}

	test_crew = []

func after_test():
	"""Test-level cleanup - runs after EACH test"""
	test_character = {}
	test_captain = {}
	test_crew = []

# ============================================================================
# _advance_character() Tests (6 tests)
# ============================================================================

func test_advance_character_success_returns_true():
	"""Successful advancement returns true"""
	test_character["experience"] = 10
	test_character["combat_skill"] = 2

	var success = helper._advance_character(test_character, "combat_skill")

	assert_that(success).is_true()

func test_advance_character_deducts_xp():
	"""Successful advancement deducts XP cost"""
	test_character["experience"] = 10
	test_character["combat_skill"] = 2

	helper._advance_character(test_character, "combat_skill")

	# Cost is 7, so 10 - 7 = 3
	assert_that(test_character["experience"]).is_equal(3)

func test_advance_character_increases_stat():
	"""Successful advancement increases stat by 1"""
	test_character["experience"] = 10
	test_character["combat_skill"] = 2

	helper._advance_character(test_character, "combat_skill")

	assert_that(test_character["combat_skill"]).is_equal(3)

func test_advance_character_insufficient_xp_returns_false():
	"""Advancement with insufficient XP returns false"""
	test_character["experience"] = 5  # Combat skill costs 7
	test_character["combat_skill"] = 2

	var success = helper._advance_character(test_character, "combat_skill")

	assert_that(success).is_false()

func test_advance_character_insufficient_xp_no_change():
	"""Failed advancement does not modify character"""
	test_character["experience"] = 5
	test_character["combat_skill"] = 2

	helper._advance_character(test_character, "combat_skill")

	# Should remain unchanged
	assert_that(test_character["experience"]).is_equal(5)
	assert_that(test_character["combat_skill"]).is_equal(2)

func test_advance_character_at_maximum_returns_false():
	"""Advancement when already at maximum returns false"""
	test_character["experience"] = 100
	test_character["combat_skill"] = 5  # Maximum value

	var success = helper._advance_character(test_character, "combat_skill")

	assert_that(success).is_false()
	assert_that(test_character["combat_skill"]).is_equal(5)  # Unchanged

# ============================================================================
# _process_character_advancements() Tests (5 tests)
# ============================================================================

func test_process_advancements_captain_only():
	"""Process advancements for captain with no crew"""
	test_captain["experience"] = 20
	test_captain["combat_skill"] = 2  # Can advance for 7 XP
	test_captain["reactions"] = 1  # Can advance for 7 XP

	var results = helper._process_character_advancements([], test_captain)

	assert_that(results).is_not_null()
	assert_dict(results).contains_keys(["captain_advancements", "crew_advancements"])
	assert_that(results.captain_advancements).is_not_empty()

func test_process_advancements_crew_only():
	"""Process advancements for crew with captain at max"""
	test_captain["experience"] = 0  # Cannot advance

	var crew_member = {
		"character_name": "Test Crew",
		"experience": 10,
		"reactions": 1,
		"combat_skill": 2,
		"speed": 5,
		"savvy": 1,
		"toughness": 4,
		"luck": 1
	}
	test_crew.append(crew_member)

	var results = helper._process_character_advancements(test_crew, test_captain)

	assert_that(results.crew_advancements).is_not_empty()
	assert_dict(results.crew_advancements).contains_keys(["Test Crew"])

func test_process_advancements_priority_order():
	"""Advancements follow priority: combat_skill > reactions > toughness > speed > savvy > luck"""
	test_captain["experience"] = 15  # Enough for 2 advancements (7+7 or 7+5)
	test_captain["combat_skill"] = 2  # Can advance
	test_captain["reactions"] = 1  # Can advance
	test_captain["speed"] = 5  # Can advance

	var results = helper._process_character_advancements([], test_captain)

	# Should advance combat_skill first (priority 1), then reactions (priority 2)
	assert_that(results.captain_advancements).has_size(2)
	assert_that(results.captain_advancements[0]).is_equal("combat_skill")
	assert_that(results.captain_advancements[1]).is_equal("reactions")

func test_process_advancements_both_captain_and_crew():
	"""Process advancements for both captain and crew"""
	test_captain["experience"] = 10
	test_captain["combat_skill"] = 2

	var crew_member = {
		"character_name": "Test Crew",
		"experience": 10,
		"reactions": 1,
		"combat_skill": 2,
		"speed": 5,
		"savvy": 1,
		"toughness": 4,
		"luck": 1
	}
	test_crew.append(crew_member)

	var results = helper._process_character_advancements(test_crew, test_captain)

	assert_that(results.captain_advancements).is_not_empty()
	assert_that(results.crew_advancements).is_not_empty()

func test_process_advancements_empty_crew():
	"""Process advancements with empty crew array"""
	test_captain["experience"] = 10
	test_captain["combat_skill"] = 2

	var results = helper._process_character_advancements([], test_captain)

	assert_that(results).is_not_null()
	assert_that(results.crew_advancements).is_empty()
