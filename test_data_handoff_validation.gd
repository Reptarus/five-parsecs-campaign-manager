extends Node

## Temporary validation script to test data handoff fixes
## Run with: godot --script test_data_handoff_validation.gd

const CampaignCreationCoordinator = preload("res://src/ui/screens/campaign/CampaignCreationCoordinator.gd")

func _ready() -> void:
	print("\n=== DATA HANDOFF VALIDATION TEST ===\n")
	
	var all_tests_passed = true
	
	# Test 1: Captain name extraction from flat structure
	all_tests_passed = test_captain_flat_structure() and all_tests_passed
	
	# Test 2: Captain name extraction from nested structure  
	all_tests_passed = test_captain_nested_structure() and all_tests_passed
	
	# Test 3: Character to Dictionary conversion
	all_tests_passed = test_character_to_dict_conversion() and all_tests_passed
	
	# Test 4: Null safety
	all_tests_passed = test_null_safety() and all_tests_passed
	
	# Test 5: Complete flow
	all_tests_passed = test_complete_data_flow() and all_tests_passed
	
	print("\n=== RESULTS ===")
	if all_tests_passed:
		print("✅ ALL TESTS PASSED - Data handoff fixes validated!")
	else:
		print("❌ SOME TESTS FAILED - Check output above")
	
	get_tree().quit()


func test_captain_flat_structure() -> bool:
	print("TEST 1: Captain name extraction (flat structure)")
	var coordinator = CampaignCreationCoordinator.new()
	
	var captain_data = {
		"name": "Captain Kirk",
		"background": "Military",
		"motivation": "Wealth"
	}
	
	coordinator.update_captain_state(captain_data)
	var state = coordinator.get_unified_campaign_state()
	
	if state.captain.name == "Captain Kirk" and \
	   state.captain.background == "Military" and \
	   state.captain.motivation == "Wealth":
		print("  ✅ PASS - Flat structure extraction works")
		coordinator.free()
		return true
	else:
		print("  ❌ FAIL - Expected 'Captain Kirk', got '%s'" % state.captain.name)
		coordinator.free()
		return false


func test_captain_nested_structure() -> bool:
	print("\nTEST 2: Captain name extraction (nested structure)")
	var coordinator = CampaignCreationCoordinator.new()
	
	var captain_data = {
		"captain": {
			"character_name": "Captain Picard",
			"background": "Explorer",
			"motivation": "Discovery"
		}
	}
	
	coordinator.update_captain_state(captain_data)
	var state = coordinator.get_unified_campaign_state()
	
	if state.captain.name == "Captain Picard" and \
	   state.captain.background == "Explorer":
		print("  ✅ PASS - Nested structure extraction works")
		coordinator.free()
		return true
	else:
		print("  ❌ FAIL - Expected 'Captain Picard', got '%s'" % state.captain.name)
		coordinator.free()
		return false


func test_character_to_dict_conversion() -> bool:
	print("\nTEST 3: Character to Dictionary conversion")
	var coordinator = CampaignCreationCoordinator.new()
	
	# Mock character as Dictionary (simulating Character object)
	var mock_character = {
		"character_name": "Test Character",
		"background": "Warrior",
		"combat": 5,
		"reactions": 3
	}
	
	var result = coordinator._character_to_dict(mock_character)
	
	if result.has("character_name") and result.character_name == "Test Character" and \
	   result.has("name") and result.name == "Test Character" and \
	   result.has("combat") and result.combat == 5:
		print("  ✅ PASS - Character conversion works")
		coordinator.free()
		return true
	else:
		print("  ❌ FAIL - Conversion missing keys or values incorrect")
		print("  Result: ", result)
		coordinator.free()
		return false


func test_null_safety() -> bool:
	print("\nTEST 4: Null safety handling")
	var coordinator = CampaignCreationCoordinator.new()
	
	var result = coordinator._character_to_dict(null)
	
	if result != null and result is Dictionary and result.is_empty():
		print("  ✅ PASS - Null returns empty Dictionary safely")
		coordinator.free()
		return true
	else:
		print("  ❌ FAIL - Null handling incorrect")
		coordinator.free()
		return false


func test_complete_data_flow() -> bool:
	print("\nTEST 5: Complete data flow (Config → Captain → Crew)")
	var coordinator = CampaignCreationCoordinator.new()
	
	# Step 1: Config
	coordinator.update_config_state({
		"campaign_name": "Integration Test",
		"difficulty": "Normal"
	})
	
	# Step 2: Captain  
	coordinator.update_captain_state({
		"captain": {
			"character_name": "Captain Integration",
			"background": "Military"
		}
	})
	
	# Step 3: Crew
	coordinator.update_crew_state({
		"members": [
			{"character_name": "Crew 1", "combat": 5},
			{"character_name": "Crew 2", "combat": 6}
		]
	})
	
	# Get unified state
	var state = coordinator.get_unified_campaign_state()
	
	# Validate
	var config_ok = state.config.campaign_name == "Integration Test"
	var captain_ok = state.captain.name == "Captain Integration"
	var crew_ok = state.crew.members.size() == 2
	var crew_dict_ok = true
	
	# Check all crew members are Dictionaries
	for member in state.crew.members:
		if not (member is Dictionary):
			crew_dict_ok = false
			break
	
	if config_ok and captain_ok and crew_ok and crew_dict_ok:
		print("  ✅ PASS - Complete data flow works")
		print("    - Campaign: %s" % state.config.campaign_name)
		print("    - Captain: %s" % state.captain.name)
		print("    - Crew: %d members (all Dictionaries)" % state.crew.members.size())
		coordinator.free()
		return true
	else:
		print("  ❌ FAIL - Data flow broken")
		print("    - Config OK: %s" % config_ok)
		print("    - Captain OK: %s" % captain_ok)
		print("    - Crew OK: %s" % crew_ok)
		print("    - Crew Dicts OK: %s" % crew_dict_ok)
		coordinator.free()
		return false
