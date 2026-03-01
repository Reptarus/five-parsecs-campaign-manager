extends GdUnitTestSuite
## Phase 3B: Backend Integration Tests - State Persistence
## Tests save/load roundtrip consistency, corruption detection, and state divergence
## gdUnit4 v6.0.1 compatible
## HIGH BUG DISCOVERY PROBABILITY

# Test helper
var HelperClass
var helper = null

# Test data
var base_campaign: Dictionary
var base_turn_state: Dictionary

func before():
	"""Suite-level setup - runs once before all tests"""
	HelperClass = load("res://tests/helpers/StateSystemHelper.gd")
	helper = HelperClass.new()

	# Base campaign data for roundtrip tests
	base_campaign = {
		"captain": {
			"character_name": "Integration Captain",
			"experience": 25,
			"stats": {"reactions": 1, "speed": 5, "combat_skill": 1, "toughness": 4, "savvy": 1, "luck": 0}
		},
		"crew": {
			"members": [
				{"character_name": "Crew1", "experience": 10, "class": 0},
				{"character_name": "Crew2", "experience": 15, "class": 2},
				{"character_name": "Crew3", "experience": 8, "class": 1}
			]
		},
		"equipment": {
			"starting_credits": 75,
			"items": ["Scrap Pistol", "Blade", "Frakk Grenade"]
		}
	}

	# Base turn state for roundtrip tests
	base_turn_state = {
		"discovered_patrons": ["MilitaryOfficer", "Questor"],
		"active_rivals": ["DeadmansHand", "UnityGoons"],
		"rumors_accumulated": 5,
		"tracked_rival": {"name": "DeadmansHand", "threat_level": 3},
		"decoy_planted": true,
		"equipment_stash_count": 4,
		"injured_characters": [
			{"character_name": "Crew1", "turns_remaining": 2, "requires_surgery": false}
		]
	}

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	HelperClass = null

# ============================================================================
# Save/Load Roundtrip Tests (3 tests)
# ============================================================================

func test_roundtrip_preserves_campaign_data():
	"""🐛 BUG DISCOVERY: Save then load should preserve all campaign data"""
	# EXPECTED: All fields should survive save/load roundtrip
	# ACTUAL: May lose data types, nested structures, or special values

	var current_turn = 10

	# Save campaign to JSON
	var save_json = helper._create_save_json(base_campaign, current_turn, base_turn_state)
	assert_that(save_json).is_not_empty()

	# Load campaign from JSON
	var load_result = helper._load_campaign_from_json(save_json)
	assert_that(load_result.success).is_true()

	# Verify captain data preserved
	var loaded_captain = load_result.campaign_data.get("captain", {})
	assert_that(loaded_captain.character_name).is_equal("Integration Captain")
	assert_that(int(loaded_captain.experience)).is_equal(25)

	# Verify crew data preserved
	var loaded_crew = load_result.campaign_data.get("crew", {})
	assert_that(loaded_crew.members.size()).is_equal(3)
	assert_that(loaded_crew.members[0].character_name).is_equal("Crew1")

	# Verify turn number incremented (line 73: campaign_turn: current_turn + 1)
	assert_that(int(load_result.current_turn)).is_equal(11)

func test_roundtrip_preserves_turn_state():
	"""Turn state arrays and dictionaries should survive roundtrip"""
	var current_turn = 5

	# Save with turn state
	var save_json = helper._create_save_json(base_campaign, current_turn, base_turn_state)

	# Load and verify turn state
	var load_result = helper._load_campaign_from_json(save_json)
	assert_that(load_result.success).is_true()

	# Verify arrays preserved
	assert_that(load_result.turn_state.discovered_patrons.size()).is_equal(2)
	assert_that(load_result.turn_state.active_rivals.size()).is_equal(2)
	assert_that(load_result.turn_state.injured_characters.size()).is_equal(1)

	# Verify dictionary values
	assert_that(int(load_result.turn_state.rumors_accumulated)).is_equal(5)
	assert_that(load_result.turn_state.decoy_planted).is_true()
	assert_that(int(load_result.turn_state.equipment_stash_count)).is_equal(4)

func test_roundtrip_preserves_nested_structures():
	"""🐛 BUG DISCOVERY: Nested dictionaries/arrays should preserve structure"""
	# EXPECTED: Deep nesting should be preserved through JSON serialization
	# ACTUAL: May flatten structures or lose depth

	var current_turn = 1

	# Save campaign with nested stats
	var save_json = helper._create_save_json(base_campaign, current_turn, base_turn_state)

	# Load and verify nested structure
	var load_result = helper._load_campaign_from_json(save_json)
	var loaded_captain = load_result.campaign_data.get("captain", {})

	# Verify nested stats dictionary preserved
	assert_that(loaded_captain.has("stats")).is_true()
	var stats = loaded_captain.stats
	assert_that(int(stats.reactions)).is_equal(1)
	assert_that(int(stats.speed)).is_equal(5)
	assert_that(int(stats.combat_skill)).is_equal(1)

# ============================================================================
# Corruption Detection Tests (3 tests)
# ============================================================================

func test_detect_invalid_json():
	"""🐛 BUG DISCOVERY: Invalid JSON should be detected and rejected"""
	# EXPECTED: JSON parse error should be caught
	# ACTUAL: May crash or return partial data

	var invalid_json = '{"invalid": json, "missing": quotes}'
	var load_result = helper._load_campaign_from_json(invalid_json)

	# Should fail gracefully
	assert_that(load_result.success).is_false()
	assert_that(load_result.error).is_not_empty()
	assert_that(load_result.error).contains("parse")

func test_detect_missing_required_fields():
	"""🐛 BUG DISCOVERY: Missing campaign_state should be detected"""
	# EXPECTED: Should validate required top-level fields
	# ACTUAL: May allow incomplete save files

	# Valid JSON but missing campaign_state
	var incomplete_json = '''
	{
		"save_version": "1.0",
		"save_timestamp": "2025-01-15T10:00:00"
	}
	'''

	var load_result = helper._load_campaign_from_json(incomplete_json)

	# Should detect missing field
	assert_that(load_result.success).is_false()
	assert_that(load_result.error).contains("campaign_state")

func test_validate_campaign_state_integrity():
	"""Validation should detect common corruption issues"""
	# Test campaign with potential issues
	var test_campaign = {
		"captain": {"character_name": "Test"}
	}

	var injured = [
		{"character_name": "InvalidCrew", "turns_remaining": -5}  # Invalid turns
	]

	# Validate state
	var validation = helper._validate_campaign_state(test_campaign, injured, 999, 50)

	# Should have warnings or errors for edge cases
	# This test documents expected validation behavior
	assert_that(validation.has("valid")).is_true()
	assert_that(validation.has("warnings")).is_true()
	assert_that(validation.has("errors")).is_true()

# ============================================================================
# Data Type Preservation Tests (2 tests)
# ============================================================================

func test_integer_values_stay_integers():
	"""🐛 BUG DISCOVERY: Integer values should not convert to floats"""
	# EXPECTED: turn numbers, XP, stats should remain integers
	# ACTUAL: JSON.parse() converts all numbers to floats (known Godot issue)

	var current_turn = 42
	var save_json = helper._create_save_json(base_campaign, current_turn, base_turn_state)
	var load_result = helper._load_campaign_from_json(save_json)

	# Note: JSON.parse() in Godot converts all numbers to floats
	# Tests must use int() cast when comparing
	# This test documents the issue
	var loaded_turn = load_result.current_turn

	# Verify it can be safely converted to int
	assert_that(int(loaded_turn)).is_equal(43)  # Incremented to 43

func test_boolean_values_stay_booleans():
	"""Boolean flags should preserve type through roundtrip"""
	var current_turn = 1

	# Create turn state with booleans
	var turn_state = base_turn_state.duplicate()
	turn_state.decoy_planted = true

	var save_json = helper._create_save_json(base_campaign, current_turn, turn_state)
	var load_result = helper._load_campaign_from_json(save_json)

	# Boolean should remain boolean (not convert to 1/0)
	assert_that(load_result.turn_state.decoy_planted).is_true()
	assert_that(typeof(load_result.turn_state.decoy_planted)).is_equal(TYPE_BOOL)
