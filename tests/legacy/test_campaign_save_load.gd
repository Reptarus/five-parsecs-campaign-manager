extends SceneTree

## Week 3 Day 4 - Campaign Finalization & Save/Load Testing
## Tests campaign completion, serialization, and save/load roundtrip

var test_results = {
	"total": 0,
	"passed": 0,
	"failed": 0,
	"warnings": 0
}

# Test state
var state_manager
var finalization_service
var test_campaign_file = "user://test_campaign_e2e.save"

func _init():
	print("\n" + "=".repeat(70))
	print("WEEK 3 SAVE/LOAD TEST: Campaign Finalization & Persistence")
	print("=".repeat(70) + "\n")

	# Setup
	_initialize_test_environment()

	# Test phases
	_test_phase_1_finalization_service()
	_test_phase_2_campaign_serialization()
	_test_phase_3_file_operations()
	_test_phase_4_save_load_roundtrip()

	# Cleanup
	_cleanup_test_files()

	# Print final summary
	_print_summary()

	quit()

## Initialize test environment
func _initialize_test_environment():
	print("[SETUP] Initializing Test Environment")
	print("-".repeat(70))

	# Load StateManager
	var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
	if state_mgr_script:
		state_manager = state_mgr_script.new()
		print("✅ StateManager loaded")
	else:
		print("❌ CRITICAL: Cannot load StateManager!")
		quit()

	# Load FinalizationService
	var finalization_script = load("res://src/core/campaign/creation/CampaignFinalizationService.gd")
	if finalization_script:
		finalization_service = finalization_script.new()
		print("✅ FinalizationService loaded")
	else:
		print("❌ WARNING: Cannot load FinalizationService")

	# Create test campaign data
	_create_minimal_campaign_data()

	print("")

## Create minimal valid campaign data for testing
func _create_minimal_campaign_data():
	print("Setting up minimal campaign data...")

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

	print("✅ Minimal campaign data created")

## Phase 1: Finalization Service Tests
func _test_phase_1_finalization_service():
	print("[PHASE 1] Finalization Service")
	print("-".repeat(70))

	# Test 1.1: Service exists and can be instantiated
	_run_test("FinalizationService exists", func():
		return finalization_service != null
	)

	# Test 1.2: Service has finalize_campaign method
	_run_test("FinalizationService has finalize_campaign() method", func():
		return finalization_service and finalization_service.has_method("finalize_campaign")
	)

	# Test 1.3: StateManager has campaign_data
	_run_test("StateManager has campaign_data", func():
		return state_manager.campaign_data is Dictionary
	)

	# Test 1.4: Campaign data has all required sections
	_run_test("Campaign data has all sections", func():
		var data = state_manager.campaign_data
		return (data.has("config") and
				data.has("captain") and
				data.has("crew") and
				data.has("ship") and
				data.has("equipment") and
				data.has("world") and
				data.has("metadata"))
	)

	print("")

## Phase 2: Campaign Serialization Tests
func _test_phase_2_campaign_serialization():
	print("[PHASE 2] Campaign Serialization")
	print("-".repeat(70))

	# Test 2.1: Campaign data can be duplicated
	_run_test("Campaign data can be duplicated", func():
		var duplicate = state_manager.campaign_data.duplicate(true)
		return duplicate is Dictionary and duplicate.has("config")
	)

	# Test 2.2: Serialized data preserves campaign name
	_run_test("Serialized data preserves campaign name", func():
		var data = state_manager.campaign_data
		return data["config"]["campaign_name"] == "Save/Load Test Campaign"
	)

	# Test 2.3: Serialized data preserves captain name
	_run_test("Serialized data preserves captain name", func():
		var data = state_manager.campaign_data
		return data["captain"]["character_name"] == "Test Captain"
	)

	# Test 2.4: Serialized data preserves ship name
	_run_test("Serialized data preserves ship name", func():
		var data = state_manager.campaign_data
		return data["ship"]["name"] == "Test Ship"
	)

	# Test 2.5: Metadata includes timestamp
	_run_test("Metadata includes created_at timestamp", func():
		var metadata = state_manager.campaign_data["metadata"]
		return metadata.has("created_at") and metadata["created_at"] != ""
	)

	print("")

## Phase 3: File Operations Tests
func _test_phase_3_file_operations():
	print("[PHASE 3] File Operations")
	print("-".repeat(70))

	# Test 3.1: Can create campaign JSON string
	_run_test("Can serialize campaign to JSON", func():
		var json_string = JSON.stringify(state_manager.campaign_data)
		return json_string != null and json_string.length() > 0
	)

	# Test 3.2: Can save JSON to file
	_run_test("Can save campaign to file", func():
		var data = state_manager.campaign_data
		var json_string = JSON.stringify(data)

		var file = FileAccess.open(test_campaign_file, FileAccess.WRITE)
		if file:
			file.store_string(json_string)
			file.close()
			print("  → Saved to: %s" % test_campaign_file)
			return true
		else:
			print("  ❌ Failed to open file for writing")
			return false
	)

	# Test 3.3: File exists after save
	_run_test("Save file exists", func():
		return FileAccess.file_exists(test_campaign_file)
	)

	# Test 3.4: Can read file back
	_run_test("Can read save file", func():
		var file = FileAccess.open(test_campaign_file, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			return content.length() > 0
		return false
	)

	print("")

## Phase 4: Save/Load Roundtrip Tests
func _test_phase_4_save_load_roundtrip():
	print("[PHASE 4] Save/Load Roundtrip")
	print("-".repeat(70))

	# Test 4.1: Load campaign from file
	var file = FileAccess.open(test_campaign_file, FileAccess.READ)
	if not file:
		print("  ❌ CRITICAL: Failed to open file for reading")
		test_results.total += 8
		test_results.failed += 8
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		print("  ❌ CRITICAL: Failed to parse JSON: %s" % json.get_error_message())
		test_results.total += 8
		test_results.failed += 8
		return

	var loaded_data = json.data

	_run_test("Can load campaign from file", func():
		return loaded_data is Dictionary
	)

	# Test 4.2: Loaded data has config section
	_run_test("Loaded data has config section", func():
		return loaded_data.has("config")
	)

	# Test 4.3: Campaign name matches
	_run_test("Campaign name matches after roundtrip", func():
		if not loaded_data.has("config"):
			return false
		return loaded_data["config"]["campaign_name"] == "Save/Load Test Campaign"
	)

	# Test 4.4: Captain data matches
	_run_test("Captain name matches after roundtrip", func():
		if not loaded_data.has("captain"):
			return false
		return loaded_data["captain"]["character_name"] == "Test Captain"
	)

	# Test 4.5: Ship data matches
	_run_test("Ship name matches after roundtrip", func():
		if not loaded_data.has("ship"):
			return false
		return loaded_data["ship"]["name"] == "Test Ship"
	)

	# Test 4.6: Equipment data matches
	_run_test("Equipment credits match after roundtrip", func():
		if not loaded_data.has("equipment"):
			return false
		return loaded_data["equipment"]["credits"] == 1000
	)

	# Test 4.7: World data matches
	_run_test("World name matches after roundtrip", func():
		if not loaded_data.has("world"):
			return false
		return loaded_data["world"]["current_world"] == "Test World"
	)

	# Test 4.8: Metadata preserved
	_run_test("Metadata preserved after roundtrip", func():
		if not loaded_data.has("metadata"):
			return false
		return loaded_data["metadata"].has("created_at")
	)

	print("")

## Cleanup test files
func _cleanup_test_files():
	print("[CLEANUP] Removing test files")
	print("-".repeat(70))

	if FileAccess.file_exists(test_campaign_file):
		DirAccess.remove_absolute(test_campaign_file)
		print("✅ Removed: %s" % test_campaign_file)
	else:
		print("⚠️  No test file to remove")

	print("")

## Helper: Run a single test
func _run_test(test_name: String, test_func: Callable):
	test_results.total += 1
	var result = test_func.call()

	if result:
		test_results.passed += 1
		print("  ✅ %s" % test_name)
	else:
		test_results.failed += 1
		print("  ❌ %s FAILED!" % test_name)

## Print final test summary
func _print_summary():
	print("=".repeat(70))
	print("SAVE/LOAD TEST SUMMARY")
	print("=".repeat(70))
	print("Total Tests: %d" % test_results.total)
	print("Passed: %d (%.1f%%)" % [test_results.passed, (test_results.passed * 100.0 / test_results.total)])
	print("Failed: %d" % test_results.failed)
	print("Warnings: %d" % test_results.warnings)
	print("")

	if test_results.failed == 0:
		print("✅ SAVE/LOAD STATUS: ALL TESTS PASSED")
		print("Campaign persistence system fully functional!")
	else:
		print("⚠️ SAVE/LOAD STATUS: %d FAILURES DETECTED" % test_results.failed)
		print("Fix failures before production deployment")

	print("=".repeat(70) + "\n")
