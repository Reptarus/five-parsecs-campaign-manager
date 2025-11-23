extends GdUnitTestSuite
## Phase 5A: State Persistence Tests - Part 2: Validation
## Tests campaign state validation for data integrity
## gdUnit4 v6.0.1 compatible

# System under test
var HelperClass
var helper

# Test data
var valid_campaign: Dictionary
var valid_injuries: Array

func before():
	"""Suite-level setup - runs once before all tests"""
	HelperClass = load("res://tests/helpers/StateSystemHelper.gd")
	helper = HelperClass.new()

func before_test():
	"""Test-level setup - reset data before each test"""
	valid_campaign = {
		"captain": {
			"character_name": "ValidCaptain",
			"experience": 25
		},
		"crew": {
			"members": [
				{"character_name": "Crew1", "experience": 10},
				{"character_name": "Crew2", "experience": 15}
			]
		},
		"equipment": {
			"starting_credits": 50
		}
	}

	valid_injuries = [
		{"name": "Crew1", "turns_remaining": 2}
	]

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	HelperClass = null

# ============================================================================
# _validate_campaign_state() Tests - Valid State (1 test)
# ============================================================================

func test_validation_all_fields_valid():
	"""Campaign with all valid fields passes validation"""
	var result = helper._validate_campaign_state(valid_campaign, valid_injuries, 3, 5)

	assert_that(result.valid).is_true()
	assert_that(result.errors).has_size(0)
	assert_that(result.warnings).has_size(0)

# ============================================================================
# _validate_campaign_state() Tests - Crew Validation (2 tests)
# ============================================================================

func test_validation_crew_missing_name_error():
	"""Crew member missing character_name triggers error"""
	var invalid_crew = valid_campaign.duplicate(true)
	invalid_crew.crew.members = [{"experience": 10}]  # Missing character_name

	var result = helper._validate_campaign_state(invalid_crew, [], 0, 0)

	assert_that(result.valid).is_false()
	assert_that(result.errors).has_size(1)
	assert_that(result.errors[0]).contains("character_name")

func test_validation_crew_missing_experience_warning():
	"""Crew member missing experience triggers warning"""
	var no_exp_crew = valid_campaign.duplicate(true)
	no_exp_crew.crew.members = [{"character_name": "TestCrew"}]  # Missing experience

	var result = helper._validate_campaign_state(no_exp_crew, [], 0, 0)

	assert_that(result.valid).is_true()  # Warning, not error
	assert_that(result.warnings).has_size(1)
	assert_that(result.warnings[0]).contains("experience field")

# ============================================================================
# _validate_campaign_state() Tests - Captain Validation (2 tests)
# ============================================================================

func test_validation_empty_captain_error():
	"""Campaign with empty captain data triggers error"""
	var no_captain = {"crew": {"members": []}, "equipment": {"starting_credits": 0}}

	var result = helper._validate_campaign_state(no_captain, [], 0, 0)

	assert_that(result.valid).is_false()
	assert_that(result.errors).has_size(1)
	assert_that(result.errors[0]).contains("captain data")

func test_validation_captain_missing_experience_warning():
	"""Captain missing experience triggers warning"""
	var no_exp_captain = valid_campaign.duplicate(true)
	no_exp_captain.captain = {"character_name": "TestCaptain"}  # Missing experience

	var result = helper._validate_campaign_state(no_exp_captain, [], 0, 0)

	assert_that(result.valid).is_true()  # Warning, not error
	assert_that(result.warnings).has_size(1)
	assert_that(result.warnings[0]).contains("Captain missing experience")

# ============================================================================
# _validate_campaign_state() Tests - Injury Validation (2 tests)
# ============================================================================

func test_validation_injury_missing_name_error():
	"""Injury missing name field triggers error"""
	var invalid_injuries = [{"turns_remaining": 3}]  # Missing name

	var result = helper._validate_campaign_state(valid_campaign, invalid_injuries, 0, 0)

	assert_that(result.valid).is_false()
	assert_that(result.errors).has_size(1)
	assert_that(result.errors[0]).contains("injury data")

func test_validation_injury_missing_turns_error():
	"""Injury missing turns_remaining field triggers error"""
	var invalid_injuries = [{"name": "Crew1"}]  # Missing turns_remaining

	var result = helper._validate_campaign_state(valid_campaign, invalid_injuries, 0, 0)

	assert_that(result.valid).is_false()
	assert_that(result.errors).has_size(1)

# ============================================================================
# _validate_campaign_state() Tests - Credits/Rumors (2 tests)
# ============================================================================

func test_validation_negative_credits_warning():
	"""Negative credits triggers warning"""
	var negative_credits = valid_campaign.duplicate(true)
	negative_credits.equipment.starting_credits = -50

	var result = helper._validate_campaign_state(negative_credits, [], 0, 0)

	assert_that(result.valid).is_true()  # Warning, not error
	assert_that(result.warnings).has_size(1)
	assert_that(result.warnings[0]).contains("Negative credits")

func test_validation_negative_rumors_warning():
	"""Negative rumors triggers warning"""
	var result = helper._validate_campaign_state(valid_campaign, [], -3, 0)

	assert_that(result.valid).is_true()  # Warning, not error
	assert_that(result.warnings).has_size(1)
	assert_that(result.warnings[0]).contains("Negative rumors")

# ============================================================================
# _validate_campaign_state() Tests - Equipment Stash (2 tests)
# ============================================================================

func test_validation_negative_stash_warning():
	"""Negative equipment stash triggers warning"""
	var result = helper._validate_campaign_state(valid_campaign, [], 0, -2)

	assert_that(result.valid).is_true()  # Warning, not error
	assert_that(result.warnings).has_size(1)
	assert_that(result.warnings[0]).contains("Negative equipment stash")

func test_validation_stash_exceeds_max_warning():
	"""Equipment stash exceeding 10 triggers warning"""
	var result = helper._validate_campaign_state(valid_campaign, [], 0, 15)

	assert_that(result.valid).is_true()  # Warning, not error
	assert_that(result.warnings).has_size(1)
	assert_that(result.warnings[0]).contains("exceeds max")

# ============================================================================
# _validate_campaign_state() Tests - Combined Issues (1 test)
# ============================================================================

func test_validation_multiple_issues_combined():
	"""Multiple validation issues reported together"""
	var bad_campaign = {"captain": {}, "crew": {"members": []}, "equipment": {"starting_credits": -10}}
	var bad_injuries = [{"name": "Test"}]  # Missing turns_remaining

	var result = helper._validate_campaign_state(bad_campaign, bad_injuries, -5, 20)

	assert_that(result.valid).is_false()
	# Should have multiple errors and warnings
	assert_that(result.errors.size() + result.warnings.size()).is_greater(2)
