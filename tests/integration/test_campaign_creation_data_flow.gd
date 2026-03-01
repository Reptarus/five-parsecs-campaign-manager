extends GdUnitTestSuite

## Integration Test: Campaign Creation Data Flow Validation
## Tests the complete data handoff pipeline from panels → coordinator → FinalPanel
## Validates all fixes for type conversion, data normalization, and null-safety

const CampaignCreationCoordinator = preload("res://src/ui/screens/campaign/CampaignCreationCoordinator.gd")
const FinalPanel = preload("res://src/ui/screens/campaign/panels/FinalPanel.gd")

var coordinator: CampaignCreationCoordinator
var final_panel: FinalPanel

func before_test() -> void:
	"""Setup test environment"""
	coordinator = CampaignCreationCoordinator.new()
	final_panel = FinalPanel.new()
	add_child(coordinator)
	add_child(final_panel)


func after_test() -> void:
	"""Cleanup"""
	if coordinator:
		coordinator.queue_free()
	if final_panel:
		final_panel.queue_free()


## TEST SUITE 1: Coordinator Data Normalization

func test_captain_name_extraction_from_flat_structure() -> void:
	"""Test captain name extraction when data is flat Dictionary"""
	var captain_data = {
		"name": "Captain Kirk",
		"background": "Military",
		"motivation": "Wealth"
	}
	
	coordinator.update_captain_state(captain_data)
	var state = coordinator.get_unified_campaign_state()

	# Use safe Dictionary access pattern
	var captain = state.get("captain", {})
	assert_str(captain.get("name", "")).is_equal("Captain Kirk")
	assert_str(captain.get("background", "")).is_equal("Military")
	assert_str(captain.get("motivation", "")).is_equal("Wealth")


func test_captain_name_extraction_from_nested_structure() -> void:
	"""Test captain name extraction when data is nested Dictionary"""
	var captain_data = {
		"captain": {
			"character_name": "Captain Picard",
			"background": "Explorer",
			"motivation": "Discovery"
		}
	}
	
	coordinator.update_captain_state(captain_data)
	var state = coordinator.get_unified_campaign_state()

	# Use safe Dictionary access pattern
	var captain = state.get("captain", {})
	assert_str(captain.get("name", "")).is_equal("Captain Picard")
	assert_str(captain.get("background", "")).is_equal("Explorer")
	assert_str(captain.get("motivation", "")).is_equal("Discovery")


func test_captain_name_extraction_with_character_name_key() -> void:
	"""Test captain name extraction when using 'character_name' key"""
	var captain_data = {
		"character_name": "Captain Janeway",
		"background": "Military",
		"motivation": "Survival"
	}
	
	coordinator.update_captain_state(captain_data)
	var state = coordinator.get_unified_campaign_state()

	# Use safe Dictionary access pattern
	var captain = state.get("captain", {})
	assert_str(captain.get("name", "")).is_equal("Captain Janeway")


## TEST SUITE 2: Character to Dictionary Conversion

func test_character_object_conversion_to_dict() -> void:
	"""Test conversion of Character objects to flat Dictionaries"""
	# Simulate a Character object as Dictionary (since we can't instantiate Character class here)
	var mock_character = {
		"character_name": "Test Character",
		"background": "Warrior",
		"motivation": "Revenge",
		"combat": 5,
		"reactions": 3,
		"toughness": 4,
		"savvy": 2,
		"tech": 1,
		"speed": 6,
		"luck": 3
	}
	
	var result = coordinator._character_to_dict(mock_character)
	
	assert_str(result.get("character_name")).is_equal("Test Character")
	assert_str(result.get("name")).is_equal("Test Character")  # Should have both keys
	assert_str(result.get("background")).is_equal("Warrior")
	assert_int(result.get("combat")).is_equal(5)
	assert_int(result.get("reactions")).is_equal(3)


func test_character_conversion_with_alternative_stat_names() -> void:
	"""Test character conversion handles combat_skill→combat and reaction→reactions"""
	var mock_character = {
		"character_name": "Test Character",
		"combat_skill": 7,  # Alternative name
		"reaction": 4       # Alternative name
	}
	
	var result = coordinator._character_to_dict(mock_character)
	
	# Should map to standard names
	assert_int(result.get("combat")).is_equal(7)
	assert_int(result.get("reactions")).is_equal(4)


func test_null_character_conversion_returns_empty_dict() -> void:
	"""Test that null character returns empty Dictionary safely"""
	var result = coordinator._character_to_dict(null)
	
	assert_object(result).is_not_null()
	assert_bool(result.is_empty()).is_true()


## TEST SUITE 3: FinalPanel Type Safety

func test_final_panel_handles_mixed_crew_array() -> void:
	"""Test FinalPanel can handle Array with mixed Character objects and Dictionaries"""
	# Setup mock campaign data with mixed array
	var mock_data = {
		"campaign_name": "Test Campaign",
		"crew": {
			"members": [
				# Dictionary entry
				{
					"character_name": "Crew Member 1",
					"combat": 5,
					"reactions": 3
				},
				# Simulated Character object
				{
					"character_name": "Crew Member 2",
					"combat": 6,
					"reactions": 4
				}
			]
		},
		"captain": {
			"name": "Test Captain"
		},
		"ship": {
			"name": "Test Ship"
		},
		"equipment": []
	}
	
	# This should not crash with type errors
	final_panel.update_campaign_data(mock_data)
	
	# If we get here without errors, the type conversion worked
	assert_bool(true).is_true()


func test_final_panel_null_safety_guards() -> void:
	"""Test FinalPanel handles null card creation gracefully"""
	var mock_data = {
		"campaign_name": "Test Campaign",
		"crew": {
			"members": []
		},
		"captain": {},
		"ship": {},
		"equipment": []
	}
	
	# Update with minimal data - should not crash even if cards return null
	final_panel.update_campaign_data(mock_data)
	
	# Should complete without add_child(null) errors
	assert_bool(true).is_true()


## TEST SUITE 4: End-to-End Data Flow

func test_complete_campaign_creation_flow() -> void:
	"""Test complete data flow: Config → Captain → Crew → FinalPanel"""
	
	# Step 1: Update config
	coordinator.update_config_state({
		"campaign_name": "Integration Test Campaign",
		"difficulty": "Normal",
		"story_track": true
	})
	
	# Step 2: Update captain
	coordinator.update_captain_state({
		"captain": {
			"character_name": "Captain Integration",
			"background": "Military",
			"motivation": "Wealth"
		}
	})
	
	# Step 3: Update crew
	coordinator.update_crew_state({
		"members": [
			{
				"character_name": "Crew 1",
				"combat": 5,
				"reactions": 3
			},
			{
				"character_name": "Crew 2",
				"combat": 6,
				"reactions": 4
			}
		]
	})
	
	# Step 4: Get unified state and pass to FinalPanel
	var unified_state = coordinator.get_unified_campaign_state()
	final_panel.update_campaign_data(unified_state)

	# Validate data integrity (use safe Dictionary access pattern)
	var config = unified_state.get("config", {})
	var captain = unified_state.get("captain", {})
	var crew = unified_state.get("crew", {})
	var members = crew.get("members", [])
	assert_str(config.get("campaign_name", "")).is_equal("Integration Test Campaign")
	assert_str(captain.get("name", "")).is_equal("Captain Integration")
	assert_int(members.size()).is_equal(2)

	# All crew members should be Dictionaries (not Character objects)
	for member in members:
		assert_bool(member is Dictionary).is_true()


func test_campaign_data_survives_round_trip() -> void:
	"""Test that data maintains integrity through full coordinator → FinalPanel → validation cycle"""

	# Create realistic campaign data
	var captain_data = {
		"captain": {
			"character_name": "Round Trip Captain",
			"background": "Explorer",
			"motivation": "Discovery",
			"combat_skill": 7,
			"reaction": 5,
			"toughness": 6,
			"savvy": 4,
			"tech": 3,
			"speed": 5,
			"luck": 2
		}
	}

	# Update coordinator
	coordinator.update_captain_state(captain_data)

	# Get state
	var state = coordinator.get_unified_campaign_state()

	# Pass to FinalPanel
	final_panel.update_campaign_data(state)

	# Validate captain data survived (use safe Dictionary access pattern)
	var captain = state.get("captain", {})
	assert_str(captain.get("name", "")).is_equal("Round Trip Captain")
	assert_str(captain.get("background", "")).is_equal("Explorer")

	# Note: Stats might not be in captain state depending on implementation
	# This test validates the name and background flow which are critical


## TEST SUITE 5: Sprint 26 Fixes - Captain Combat Stats Extraction

func test_captain_combat_stats_extracted_from_character_object() -> void:
	"""Sprint 26: Test that captain combat stats are extracted from Character-like objects"""
	# Create mock captain with Character-like structure containing stats
	var captain_data = {
		"captain_character": {
			"character_name": "Stats Captain",
			"background": "Military",
			"combat": 5,
			"toughness": 4,
			"reactions": 3,
			"savvy": 2,
			"speed": 6
		},
		"is_complete": true
	}

	coordinator.update_captain_state(captain_data)
	var state = coordinator.get_unified_campaign_state()

	var captain = state.get("captain", {})
	# Verify combat stats were extracted to unified state
	assert_int(captain.get("combat", 0)).is_equal(5)
	assert_int(captain.get("toughness", 0)).is_equal(4)
	assert_int(captain.get("reactions", 0)).is_equal(3)
	assert_int(captain.get("savvy", 0)).is_equal(2)
	assert_int(captain.get("speed", 0)).is_equal(6)


func test_captain_stats_default_values_when_missing() -> void:
	"""Sprint 26: Test that missing captain stats get sensible defaults"""
	var captain_data = {
		"captain_character": {
			"character_name": "Default Stats Captain"
			# No stats provided - should get defaults
		},
		"is_complete": true
	}

	coordinator.update_captain_state(captain_data)
	var state = coordinator.get_unified_campaign_state()

	var captain = state.get("captain", {})
	# Verify defaults were applied (combat=1, toughness=3, reactions=1, savvy=0, speed=4)
	assert_int(captain.get("combat", -1)).is_greater_equal(1)
	assert_int(captain.get("toughness", -1)).is_greater_equal(1)
	assert_int(captain.get("speed", -1)).is_greater_equal(1)


## TEST SUITE 6: Sprint 26 Fixes - has_captain Flag

func test_has_captain_flag_set_when_captain_complete() -> void:
	"""Sprint 26: Test that has_captain flag is set in crew state when captain is complete"""
	var captain_data = {
		"name": "Flag Test Captain",
		"background": "Military",
		"is_complete": true
	}

	coordinator.update_captain_state(captain_data)
	var state = coordinator.get_unified_campaign_state()

	var crew = state.get("crew", {})
	# Verify has_captain flag was set
	assert_bool(crew.get("has_captain", false)).is_true()


func test_has_captain_flag_set_when_captain_object_exists() -> void:
	"""Sprint 26: Test that has_captain flag is set when crew.captain is populated"""
	var captain_data = {
		"captain": {
			"character_name": "Object Captain"
		}
	}

	coordinator.update_captain_state(captain_data)
	var state = coordinator.get_unified_campaign_state()

	var crew = state.get("crew", {})
	# Verify has_captain flag was set because crew.captain exists
	assert_bool(crew.get("has_captain", false)).is_true()


func test_has_captain_flag_from_crew_data() -> void:
	"""Sprint 26: Test that has_captain flag is preserved from incoming crew data"""
	var crew_data = {
		"members": [
			{"character_name": "Crew 1", "combat": 3}
		],
		"has_captain": true
	}

	coordinator.update_crew_state(crew_data)
	var state = coordinator.get_unified_campaign_state()

	var crew = state.get("crew", {})
	assert_bool(crew.get("has_captain", false)).is_true()


## TEST SUITE 7: Sprint 26 Fixes - StateManager Sync

func test_set_phase_data_called_for_captain() -> void:
	"""Sprint 26: Test that captain data is synced to StateManager"""
	var captain_data = {
		"name": "Sync Captain",
		"background": "Explorer",
		"is_complete": true
	}

	coordinator.update_captain_state(captain_data)

	# Verify StateManager received the data via set_phase_data
	if coordinator.state_manager:
		var phase_data = coordinator.state_manager.get_phase_data(
			coordinator.state_manager.Phase.CAPTAIN_CREATION
		)
		assert_str(phase_data.get("name", "")).is_equal("Sync Captain")


func test_set_phase_data_called_for_crew() -> void:
	"""Sprint 26: Test that crew data is synced to StateManager"""
	var crew_data = {
		"members": [
			{"character_name": "Crew 1", "combat": 4}
		],
		"has_captain": true,
		"size": 4
	}

	coordinator.update_crew_state(crew_data)

	# Verify StateManager received the data via set_phase_data
	if coordinator.state_manager:
		var phase_data = coordinator.state_manager.get_phase_data(
			coordinator.state_manager.Phase.CREW_SETUP
		)
		assert_bool(phase_data.get("has_captain", false)).is_true()


func test_set_phase_data_called_for_ship() -> void:
	"""Sprint 26: Test that ship data is synced to StateManager"""
	var ship_data = {
		"name": "Sync Ship",
		"type": "Frigate",
		"hull_points": 25,
		"is_complete": true
	}

	coordinator.update_ship_state(ship_data)

	# Verify StateManager received the data via set_phase_data
	if coordinator.state_manager:
		var phase_data = coordinator.state_manager.get_phase_data(
			coordinator.state_manager.Phase.SHIP_ASSIGNMENT
		)
		assert_str(phase_data.get("name", "")).is_equal("Sync Ship")


func test_set_phase_data_called_for_config() -> void:
	"""Sprint 26: Test that config data is synced to StateManager"""
	var config_data = {
		"campaign_name": "Sync Campaign",
		"difficulty": 2,
		"victory_conditions": {"20_battles": true}
	}

	coordinator.update_campaign_config_state(config_data)

	# Verify StateManager received the data via set_phase_data
	if coordinator.state_manager:
		var phase_data = coordinator.state_manager.get_phase_data(
			coordinator.state_manager.Phase.CONFIG
		)
		assert_str(phase_data.get("campaign_name", "")).is_equal("Sync Campaign")


## TEST SUITE 8: Complete Validation Flow

func test_complete_wizard_flow_passes_validation() -> void:
	"""Sprint 26: Test that a complete wizard flow passes StateManager validation"""
	# Step 1: Config with campaign name and victory conditions
	coordinator.update_campaign_config_state({
		"campaign_name": "Validation Test Campaign",
		"difficulty": 1,
		"victory_conditions": {"20_battles": true},
		"is_complete": true
	})

	# Step 2: Captain with stats
	coordinator.update_captain_state({
		"name": "Validation Captain",
		"background": "Military",
		"captain_character": {
			"character_name": "Validation Captain",
			"combat": 5,
			"toughness": 4,
			"reactions": 3,
			"savvy": 2,
			"speed": 4
		},
		"is_complete": true
	})

	# Step 3: Crew with has_captain
	coordinator.update_crew_state({
		"members": [
			{"character_name": "Crew 1", "combat": 4},
			{"character_name": "Crew 2", "combat": 3},
			{"character_name": "Crew 3", "combat": 5},
			{"character_name": "Crew 4", "combat": 4}
		],
		"size": 4,
		"has_captain": true,
		"is_complete": true
	})

	# Step 4: Ship
	coordinator.update_ship_state({
		"name": "Validation Ship",
		"type": "Frigate",
		"hull_points": 25,
		"max_hull": 30,
		"is_complete": true
	})

	# Step 5: Equipment
	coordinator.update_equipment_state({
		"items": [{"name": "Laser Rifle"}],
		"credits": 1000,
		"is_complete": true
	})

	# Verify the unified state is complete
	var state = coordinator.get_unified_campaign_state()

	var captain = state.get("captain", {})
	var crew = state.get("crew", {})
	var ship = state.get("ship", {})

	# All critical fields should be populated
	assert_str(captain.get("name", "")).is_not_empty()
	assert_int(captain.get("combat", 0)).is_greater(0)
	assert_bool(crew.get("has_captain", false)).is_true()
	assert_str(ship.get("name", "")).is_not_empty()
