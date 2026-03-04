extends GdUnitTestSuite
## Phase 5A: State Persistence Tests - Part 1: Save/Load
## Tests JSON save/load functionality for campaign state
## gdUnit4 v6.0.1 compatible

# System under test
var HelperClass
var helper

# Test data
var valid_save_json: String
var minimal_campaign: Dictionary
var full_campaign: Dictionary

func before():
	"""Suite-level setup - runs once before all tests"""
	HelperClass = load("res://tests/helpers/StateSystemHelper.gd")
	helper = HelperClass.new()

	# Setup valid save JSON for load tests
	valid_save_json = '''{
		"save_version": "1.0",
		"save_timestamp": "2025-01-15T10:30:00",
		"game_version": "0.1.0",
		"campaign_state": {
			"campaign_turn": 5,
			"campaign_data": {
				"captain": {
					"character_name": "Test Captain",
					"experience": 20
				},
				"crew": {
					"members": [
						{"character_name": "Crew1", "experience": 10},
						{"character_name": "Crew2", "experience": 15}
					]
				},
				"equipment": {
					"starting_credits": 50
				},
				"turn_state": {
					"discovered_patrons": ["patron1"],
					"active_rivals": ["rival1"],
					"rumors_accumulated": 3,
					"tracked_rival": {"name": "TestRival"},
					"decoy_planted": true,
					"equipment_stash_count": 2,
					"injured_characters": []
				}
			}
		}
	}'''

	# Setup minimal campaign data for save tests
	minimal_campaign = {
		"captain": {"character_name": "MinimalCaptain"}
	}

	# Setup full campaign data for save tests
	full_campaign = {
		"captain": {"character_name": "FullCaptain", "experience": 30},
		"crew": {"members": [{"character_name": "TestCrew"}]},
		"equipment": {"starting_credits": 100}
	}

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	HelperClass = null

# ============================================================================
# _load_campaign_from_json() Tests - Valid Loads (4 tests)
# ============================================================================

func test_load_valid_json_success():
	"""Valid JSON with all fields loads successfully"""
	var result = helper._load_campaign_from_json(valid_save_json)

	assert_that(result.success).is_true()
	assert_that(result.error).is_empty()
	assert_that(result.campaign_data).is_not_empty()

func test_load_extracts_current_turn():
	"""Load extracts current_turn from campaign_state"""
	var result = helper._load_campaign_from_json(valid_save_json)

	assert_that(int(result.current_turn)).is_equal(5)

func test_load_extracts_captain_data():
	"""Load extracts captain data from campaign_data"""
	var result = helper._load_campaign_from_json(valid_save_json)

	var captain = result.campaign_data.get("captain", {})
	assert_that(captain.character_name).is_equal("Test Captain")
	assert_that(int(captain.experience)).is_equal(20)

func test_load_extracts_turn_state():
	"""Load extracts all 7 turn_state fields"""
	var result = helper._load_campaign_from_json(valid_save_json)

	assert_that(result.turn_state.discovered_patrons).has_size(1)
	assert_that(result.turn_state.active_rivals).has_size(1)
	assert_that(int(result.turn_state.rumors_accumulated)).is_equal(3)
	assert_that(result.turn_state.tracked_rival).is_not_empty()
	assert_that(result.turn_state.decoy_planted).is_true()
	assert_that(int(result.turn_state.equipment_stash_count)).is_equal(2)
	assert_that(result.turn_state.injured_characters).has_size(0)

# ============================================================================
# _load_campaign_from_json() Tests - Error Handling (3 tests)
# ============================================================================

func test_load_invalid_json_syntax():
	"""Invalid JSON syntax returns error"""
	var invalid_json = '{"broken": invalid}'
	var result = helper._load_campaign_from_json(invalid_json)

	assert_that(result.success).is_false()
	assert_that(result.error).contains("parse error")

func test_load_missing_campaign_state():
	"""Missing campaign_state key returns error"""
	var missing_state = '{"save_version": "1.0"}'
	var result = helper._load_campaign_from_json(missing_state)

	assert_that(result.success).is_false()
	assert_that(result.error).contains("missing campaign_state")

func test_load_empty_turn_state_uses_defaults():
	"""Campaign without turn_state uses default empty values"""
	var no_turn_state = '''{
		"campaign_state": {
			"campaign_turn": 1,
			"campaign_data": {}
		}
	}'''
	var result = helper._load_campaign_from_json(no_turn_state)

	assert_that(result.success).is_true()
	assert_that(result.turn_state.discovered_patrons).has_size(0)
	assert_that(result.turn_state.rumors_accumulated).is_equal(0)

# ============================================================================
# _create_save_json() Tests - JSON Structure (6 tests)
# ============================================================================

func test_save_creates_valid_json():
	"""Created save JSON is valid and parseable"""
	var turn_state = {"discovered_patrons": [], "active_rivals": [], "rumors_accumulated": 0,
					  "tracked_rival": {}, "decoy_planted": false, "equipment_stash_count": 0,
					  "injured_characters": []}
	var json_string = helper._create_save_json(minimal_campaign, 1, turn_state)

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	assert_that(parse_result).is_equal(OK)

func test_save_includes_version_fields():
	"""Save JSON includes save_version and game_version"""
	var turn_state = {"discovered_patrons": [], "active_rivals": [], "rumors_accumulated": 0,
					  "tracked_rival": {}, "decoy_planted": false, "equipment_stash_count": 0,
					  "injured_characters": []}
	var json_string = helper._create_save_json(minimal_campaign, 1, turn_state)

	var json = JSON.new()
	json.parse(json_string)
	var data = json.data

	assert_that(data.save_version).is_equal("1.0")
	assert_that(data.game_version).is_equal("0.1.0")

func test_save_increments_turn():
	"""Save increments campaign_turn by 1 (saves next turn)"""
	var turn_state = {"discovered_patrons": [], "active_rivals": [], "rumors_accumulated": 0,
					  "tracked_rival": {}, "decoy_planted": false, "equipment_stash_count": 0,
					  "injured_characters": []}
	var json_string = helper._create_save_json(minimal_campaign, 3, turn_state)

	var json = JSON.new()
	json.parse(json_string)
	var data = json.data

	assert_that(int(data["campaign_state"]["campaign_turn"])).is_equal(4)  # 3 + 1

func test_save_nests_turn_state():
	"""Save nests turn_state inside campaign_data"""
	var turn_state = {"discovered_patrons": ["test"], "active_rivals": [], "rumors_accumulated": 5,
					  "tracked_rival": {}, "decoy_planted": false, "equipment_stash_count": 0,
					  "injured_characters": []}
	var json_string = helper._create_save_json(minimal_campaign, 1, turn_state)

	var json = JSON.new()
	json.parse(json_string)
	var data = json.data
	var campaign_data = data["campaign_state"]["campaign_data"]

	assert_that(campaign_data["turn_state"]).is_not_empty()
	assert_that(int(campaign_data["turn_state"]["rumors_accumulated"])).is_equal(5)

func test_save_preserves_campaign_data():
	"""Save preserves all campaign_data fields"""
	var turn_state = {"discovered_patrons": [], "active_rivals": [], "rumors_accumulated": 0,
					  "tracked_rival": {}, "decoy_planted": false, "equipment_stash_count": 0,
					  "injured_characters": []}
	var json_string = helper._create_save_json(full_campaign, 1, turn_state)

	var json = JSON.new()
	json.parse(json_string)
	var data = json.data
	var campaign_data = data["campaign_state"]["campaign_data"]

	assert_that(campaign_data["captain"]["character_name"]).is_equal("FullCaptain")
	assert_that(campaign_data["crew"]["members"]).has_size(1)
	assert_that(int(campaign_data["equipment"]["starting_credits"])).is_equal(100)

func test_save_includes_timestamp():
	"""Save includes timestamp field"""
	var turn_state = {"discovered_patrons": [], "active_rivals": [], "rumors_accumulated": 0,
					  "tracked_rival": {}, "decoy_planted": false, "equipment_stash_count": 0,
					  "injured_characters": []}
	var json_string = helper._create_save_json(minimal_campaign, 1, turn_state)

	var json = JSON.new()
	json.parse(json_string)
	var data = json.data

	assert_that(data.has("save_timestamp")).is_true()
	assert_that(data.save_timestamp).is_not_empty()
