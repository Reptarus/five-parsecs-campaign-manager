extends GdUnitTestSuite

## Week 3 Day 4 - Campaign Finalization & Save/Load Testing (gdUnit4 version)
## Tests campaign completion, serialization, and save/load roundtrip

var state_manager
var finalization_service
var test_campaign_file = "user://test_campaign_gdunit4.save"

func before_test():
	# Set deterministic seed for reproducible random numbers
	seed(12345)

	# Load StateManager
	var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
	if state_mgr_script:
		state_manager = state_mgr_script.new()
	
	# Load FinalizationService
	var finalization_script = load("res://src/core/campaign/creation/CampaignFinalizationService.gd")
	if finalization_script:
		finalization_service = finalization_script.new()
	
	# Create test campaign data
	if state_manager:
		_create_minimal_campaign_data()

func after_test():
	# Cleanup test files
	if FileAccess.file_exists(test_campaign_file):
		DirAccess.remove_absolute(test_campaign_file)
	
	# Note: state_manager and finalization_service are RefCounted objects
	# They auto-free when references drop to 0 - no manual .free() needed
	state_manager = null
	finalization_service = null

## Create minimal valid campaign data for testing
func _create_minimal_campaign_data():
	# Config phase
	state_manager.set_phase_data(state_manager.Phase.CONFIG, {
		"campaign_name": "Save/Load Test Campaign",
		"campaign_type": "standard",
		"victory_conditions": {"story_points": true},
		"story_track": "test_track",
		"is_complete": true
	})
	
	# Captain phase
	state_manager.set_phase_data(state_manager.Phase.CAPTAIN_CREATION, {
		"character_name": "Test Captain",
		"background": 1,
		"motivation": 1,
		"class": 1,
		"stats": {"reactions": 1, "speed": 5, "combat_skill": 1, "toughness": 4, "savvy": 1},
		"is_complete": true
	})
	
	# Crew phase
	state_manager.set_phase_data(state_manager.Phase.CREW_SETUP, {
		"members": [{"character_name": "Crew 1"}],
		"size": 1,
		"has_captain": true,
		"is_complete": true
	})
	
	# Ship phase
	state_manager.set_phase_data(state_manager.Phase.SHIP_ASSIGNMENT, {
		"name": "Test Ship",
		"type": "light_freighter",
		"hull_points": 6,
		"is_complete": true
	})
	
	# Equipment phase
	state_manager.set_phase_data(state_manager.Phase.EQUIPMENT_GENERATION, {
		"equipment": ["Basic Weapon"],
		"credits": 1000,
		"is_complete": true
	})
	
	# World phase
	state_manager.set_phase_data(state_manager.Phase.WORLD_GENERATION, {
		"current_world": "Test World",
		"world_type": "colony",
		"is_complete": true
	})

## Phase 1: Finalization Service Tests
func test_finalization_service_exists():
	assert_that(finalization_service).is_not_null()

func test_finalization_service_has_finalize_campaign_method():
	if finalization_service:
		assert_that(finalization_service.has_method("finalize_campaign")).is_true()

func test_state_manager_has_campaign_data():
	assert_that(state_manager).is_not_null()
	assert_bool(state_manager.campaign_data is Dictionary).is_true()

func test_campaign_data_has_all_required_sections():
	var data = state_manager.campaign_data
	assert_that(data.has("config")).is_true()
	assert_that(data.has("captain")).is_true()
	assert_that(data.has("crew")).is_true()
	assert_that(data.has("ship")).is_true()
	assert_that(data.has("equipment")).is_true()
	assert_that(data.has("world")).is_true()
	assert_that(data.has("metadata")).is_true()

## Phase 2: Campaign Serialization Tests
func test_campaign_data_can_be_duplicated():
	var duplicate = state_manager.campaign_data.duplicate(true)
	assert_bool(duplicate is Dictionary).is_true()
	assert_that(duplicate.has("config")).is_true()

func test_serialized_data_preserves_campaign_name():
	var data = state_manager.campaign_data
	assert_that(data["config"]["campaign_name"]).is_equal("Save/Load Test Campaign")

func test_serialized_data_preserves_captain_name():
	var data = state_manager.campaign_data
	assert_that(data["captain"]["character_name"]).is_equal("Test Captain")

func test_serialized_data_preserves_ship_name():
	var data = state_manager.campaign_data
	assert_that(data["ship"]["name"]).is_equal("Test Ship")

func test_metadata_includes_timestamp():
	var metadata = state_manager.campaign_data["metadata"]
	assert_that(metadata.has("created_at")).is_true()
	assert_that(metadata["created_at"]).is_not_equal("")

## Phase 3: File Operations Tests
func test_can_serialize_campaign_to_json():
	var json_string = JSON.stringify(state_manager.campaign_data)
	assert_that(json_string).is_not_null()
	assert_that(json_string.length()).is_greater(0)

func test_can_save_campaign_to_file():
	var data = state_manager.campaign_data
	var json_string = JSON.stringify(data)
	
	var file = FileAccess.open(test_campaign_file, FileAccess.WRITE)
	assert_that(file).is_not_null()
	
	if file:
		file.store_string(json_string)
		file.close()
	
	assert_that(FileAccess.file_exists(test_campaign_file)).is_true()

func test_save_file_exists_after_save():
	# First save the file
	var data = state_manager.campaign_data
	var json_string = JSON.stringify(data)
	var file = FileAccess.open(test_campaign_file, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	
	# Then verify it exists
	assert_that(FileAccess.file_exists(test_campaign_file)).is_true()

func test_can_read_save_file():
	# First save the file
	var data = state_manager.campaign_data
	var json_string = JSON.stringify(data)
	var save_file = FileAccess.open(test_campaign_file, FileAccess.WRITE)
	if save_file:
		save_file.store_string(json_string)
		save_file.close()
	
	# Then read it back
	var read_file = FileAccess.open(test_campaign_file, FileAccess.READ)
	assert_that(read_file).is_not_null()
	
	if read_file:
		var content = read_file.get_as_text()
		read_file.close()
		assert_that(content.length()).is_greater(0)

## Phase 4: Save/Load Roundtrip Tests
func test_can_load_campaign_from_file():
	# Save the campaign
	var data = state_manager.campaign_data
	var json_string = JSON.stringify(data)
	var save_file = FileAccess.open(test_campaign_file, FileAccess.WRITE)
	if save_file:
		save_file.store_string(json_string)
		save_file.close()
	
	# Load it back
	var load_file = FileAccess.open(test_campaign_file, FileAccess.READ)
	assert_that(load_file).is_not_null()
	
	if load_file:
		var loaded_string = load_file.get_as_text()
		load_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(loaded_string)

		assert_that(parse_result).is_equal(OK)
		assert_bool(json.data is Dictionary).is_true()

func test_loaded_data_has_config_section():
	# Save and load
	var data = state_manager.campaign_data
	var json_string = JSON.stringify(data)
	var save_file = FileAccess.open(test_campaign_file, FileAccess.WRITE)
	if save_file:
		save_file.store_string(json_string)
		save_file.close()
	
	var load_file = FileAccess.open(test_campaign_file, FileAccess.READ)
	if load_file:
		var loaded_string = load_file.get_as_text()
		load_file.close()
		
		var json = JSON.new()
		json.parse(loaded_string)
		var loaded_data = json.data
		
		assert_that(loaded_data.has("config")).is_true()

func test_campaign_name_matches_after_roundtrip():
	# Save and load
	var data = state_manager.campaign_data
	var json_string = JSON.stringify(data)
	var save_file = FileAccess.open(test_campaign_file, FileAccess.WRITE)
	if save_file:
		save_file.store_string(json_string)
		save_file.close()
	
	var load_file = FileAccess.open(test_campaign_file, FileAccess.READ)
	if load_file:
		var loaded_string = load_file.get_as_text()
		load_file.close()
		
		var json = JSON.new()
		json.parse(loaded_string)
		var loaded_data = json.data
		
		assert_that(loaded_data["config"]["campaign_name"]).is_equal("Save/Load Test Campaign")

func test_captain_name_matches_after_roundtrip():
	# Save and load
	var data = state_manager.campaign_data
	var json_string = JSON.stringify(data)
	var save_file = FileAccess.open(test_campaign_file, FileAccess.WRITE)
	if save_file:
		save_file.store_string(json_string)
		save_file.close()
	
	var load_file = FileAccess.open(test_campaign_file, FileAccess.READ)
	if load_file:
		var loaded_string = load_file.get_as_text()
		load_file.close()
		
		var json = JSON.new()
		json.parse(loaded_string)
		var loaded_data = json.data
		
		assert_that(loaded_data["captain"]["character_name"]).is_equal("Test Captain")

func test_ship_name_matches_after_roundtrip():
	# Save and load
	var data = state_manager.campaign_data
	var json_string = JSON.stringify(data)
	var save_file = FileAccess.open(test_campaign_file, FileAccess.WRITE)
	if save_file:
		save_file.store_string(json_string)
		save_file.close()
	
	var load_file = FileAccess.open(test_campaign_file, FileAccess.READ)
	if load_file:
		var loaded_string = load_file.get_as_text()
		load_file.close()
		
		var json = JSON.new()
		json.parse(loaded_string)
		var loaded_data = json.data
		
		assert_that(loaded_data["ship"]["name"]).is_equal("Test Ship")

func test_equipment_credits_match_after_roundtrip():
	# Save and load
	var data = state_manager.campaign_data
	var json_string = JSON.stringify(data)
	var save_file = FileAccess.open(test_campaign_file, FileAccess.WRITE)
	if save_file:
		save_file.store_string(json_string)
		save_file.close()
	
	var load_file = FileAccess.open(test_campaign_file, FileAccess.READ)
	if load_file:
		var loaded_string = load_file.get_as_text()
		load_file.close()
		
		var json = JSON.new()
		json.parse(loaded_string)
		var loaded_data = json.data
		
		# JSON deserializes numbers as floats, so cast to int for comparison
		assert_that(int(loaded_data["equipment"]["credits"])).is_equal(1000)

func test_world_name_matches_after_roundtrip():
	# Save and load
	var data = state_manager.campaign_data
	var json_string = JSON.stringify(data)
	var save_file = FileAccess.open(test_campaign_file, FileAccess.WRITE)
	if save_file:
		save_file.store_string(json_string)
		save_file.close()
	
	var load_file = FileAccess.open(test_campaign_file, FileAccess.READ)
	if load_file:
		var loaded_string = load_file.get_as_text()
		load_file.close()
		
		var json = JSON.new()
		json.parse(loaded_string)
		var loaded_data = json.data
		
		assert_that(loaded_data["world"]["current_world"]).is_equal("Test World")

func test_metadata_preserved_after_roundtrip():
	# Save and load
	var data = state_manager.campaign_data
	var json_string = JSON.stringify(data)
	var save_file = FileAccess.open(test_campaign_file, FileAccess.WRITE)
	if save_file:
		save_file.store_string(json_string)
		save_file.close()
	
	var load_file = FileAccess.open(test_campaign_file, FileAccess.READ)
	if load_file:
		var loaded_string = load_file.get_as_text()
		load_file.close()
		
		var json = JSON.new()
		json.parse(loaded_string)
		var loaded_data = json.data
		
		assert_that(loaded_data.has("metadata")).is_true()
		assert_that(loaded_data["metadata"].has("created_at")).is_true()
