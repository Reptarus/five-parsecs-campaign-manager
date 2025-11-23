extends GdUnitTestSuite
## Phase 5C: State Persistence Tests - Part 3: Victory Conditions
## Tests campaign victory and achievement detection
## gdUnit4 v6.0.1 compatible

# System under test
var HelperClass
var helper

# Test data
var basic_campaign: Dictionary
var wealthy_campaign: Dictionary
var large_crew_campaign: Dictionary
var veteran_campaign: Dictionary

func before():
	"""Suite-level setup - runs once before all tests"""
	HelperClass = load("res://tests/helpers/StateSystemHelper.gd")
	helper = HelperClass.new()

func before_test():
	"""Test-level setup - reset data before each test"""
	basic_campaign = {
		"captain": {"character_name": "TestCaptain", "experience": 20},
		"crew": {"members": [{"character_name": "Crew1"}]},
		"equipment": {"starting_credits": 50}
	}

	wealthy_campaign = basic_campaign.duplicate(true)
	wealthy_campaign.equipment.starting_credits = 150

	large_crew_campaign = basic_campaign.duplicate(true)
	large_crew_campaign.crew.members = [
		{"character_name": "Crew1"},
		{"character_name": "Crew2"},
		{"character_name": "Crew3"},
		{"character_name": "Crew4"},
		{"character_name": "Crew5"}
	]

	veteran_campaign = basic_campaign.duplicate(true)
	veteran_campaign.captain.experience = 60

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	HelperClass = null

# ============================================================================
# _check_victory_conditions() Tests - Victory Status (2 tests)
# ============================================================================

func test_victory_achieved_at_target_turns():
	"""Campaign completing target turns achieves victory"""
	var result = helper._check_victory_conditions(basic_campaign, 10, 10, [])

	assert_that(result.victory).is_true()
	assert_that(result.conditions_met).has_size(1)
	assert_that(result.conditions_met[0]).contains("Survived 10 campaign turns")

func test_victory_not_achieved_before_target():
	"""Campaign before target turns has not achieved victory"""
	var result = helper._check_victory_conditions(basic_campaign, 5, 10, [])

	assert_that(result.victory).is_false()
	assert_that(result.conditions_met).has_size(0)

# ============================================================================
# _check_victory_conditions() Tests - Achievements (4 tests)
# ============================================================================

func test_achievement_wealthy_captain():
	"""100+ credits grants Wealthy Captain achievement"""
	var result = helper._check_victory_conditions(wealthy_campaign, 10, 10, [])

	assert_that(result.achievements.size()).is_greater_equal(1)
	var has_wealthy = false
	for achievement in result.achievements:
		if achievement.contains("Wealthy Captain"):
			has_wealthy = true
	assert_that(has_wealthy).is_true()

func test_achievement_famous_crew():
	"""5+ crew members grants Famous Crew achievement"""
	var result = helper._check_victory_conditions(large_crew_campaign, 10, 10, [])

	assert_that(result.achievements.size()).is_greater_equal(1)
	var has_famous = false
	for achievement in result.achievements:
		if achievement.contains("Famous Crew"):
			has_famous = true
	assert_that(has_famous).is_true()

func test_achievement_veteran_captain():
	"""50+ XP grants Veteran Captain achievement"""
	var result = helper._check_victory_conditions(veteran_campaign, 10, 10, [])

	assert_that(result.achievements.size()).is_greater_equal(1)
	var has_veteran = false
	for achievement in result.achievements:
		if achievement.contains("Veteran Captain"):
			has_veteran = true
	assert_that(has_veteran).is_true()

func test_achievement_iron_will():
	"""No fatal injuries grants Iron Will achievement"""
	var turn_reports = [
		{
			"phases": {
				"post_battle": {
					"injuries": [
						{"name": "Crew1", "is_fatal": false}
					]
				}
			}
		}
	]

	var result = helper._check_victory_conditions(basic_campaign, 10, 10, turn_reports)

	var has_iron_will = false
	for achievement in result.achievements:
		if achievement.contains("Iron Will"):
			has_iron_will = true
	assert_that(has_iron_will).is_true()

# ============================================================================
# _check_victory_conditions() Tests - Completion Percentage (1 test)
# ============================================================================

func test_completion_percentage_calculation():
	"""Completion percentage accurately reflects turns completed"""
	# 5 turns out of 10 = 50%
	var result = helper._check_victory_conditions(basic_campaign, 5, 10, [])

	assert_that(result.completion_percentage).is_equal(50)

	# 10 turns out of 10 = 100%
	result = helper._check_victory_conditions(basic_campaign, 10, 10, [])
	assert_that(result.completion_percentage).is_equal(100)
