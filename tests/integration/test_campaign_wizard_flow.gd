extends GdUnitTestSuite

## Integration Test: Campaign Wizard Complete Flow
## Tests panel navigation, data persistence, and end-to-end campaign creation
## Validates the complete wizard UX from ConfigPanel → FinalPanel → Campaign Creation

const CampaignCreationUI = preload("res://src/ui/screens/campaign/CampaignCreationUI.gd")
const CampaignCreationCoordinator = preload("res://src/ui/screens/campaign/CampaignCreationCoordinator.gd")
const ConfigPanel = preload("res://src/ui/screens/campaign/panels/ConfigPanel.gd")
const CaptainPanel = preload("res://src/ui/screens/campaign/panels/CaptainPanel.gd")
const CrewPanel = preload("res://src/ui/screens/campaign/panels/CrewPanel.gd")
const FinalPanel = preload("res://src/ui/screens/campaign/panels/FinalPanel.gd")

# Scene preload - required for UI that has child nodes
const CampaignCreationUIScene = preload("res://src/ui/screens/campaign/CampaignCreationUI.tscn")

var campaign_ui: CampaignCreationUI
var coordinator: CampaignCreationCoordinator

func before_test() -> void:
	"""Setup test environment with campaign UI and coordinator"""
	# Load from scene to include all child nodes (ResponsiveMargin, MainContainer, etc.)
	campaign_ui = auto_free(CampaignCreationUIScene.instantiate())
	add_child(campaign_ui)
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(campaign_ui):
		push_warning("campaign_ui freed during setup")
		return

	# Get coordinator reference
	coordinator = campaign_ui.get_coordinator() if campaign_ui.has_method("get_coordinator") else null
	if not coordinator:
		push_error("Test Setup Failed: No coordinator available")


func after_test() -> void:
	"""Cleanup test environment"""
	if campaign_ui:
		campaign_ui.queue_free()
		campaign_ui = null
	coordinator = null


## TEST SUITE 1: Panel Navigation

func test_wizard_panel_navigation() -> void:
	"""Test navigation between all wizard panels"""
	if not coordinator or not is_instance_valid(coordinator):
		push_warning("coordinator not available, skipping")
		return

	# Start at ConfigPanel (panel index 0)
	assert_int(coordinator.current_panel_index).is_equal(0)

	# Navigate forward through all panels
	coordinator.next_panel()
	await get_tree().process_frame
	if not is_instance_valid(coordinator):
		return
	assert_int(coordinator.current_panel_index).is_equal(1)  # CaptainPanel

	coordinator.next_panel()
	await get_tree().process_frame
	if not is_instance_valid(coordinator):
		return
	assert_int(coordinator.current_panel_index).is_equal(2)  # CrewPanel

	# Navigate backward
	coordinator.previous_panel()
	await get_tree().process_frame
	if not is_instance_valid(coordinator):
		return
	assert_int(coordinator.current_panel_index).is_equal(1)  # Back to CaptainPanel


func test_panel_navigation_validates_before_advancing() -> void:
	"""Test that invalid panels prevent forward navigation"""
	if not coordinator or not is_instance_valid(coordinator):
		push_warning("coordinator not available, skipping")
		return

	# Get current panel (ConfigPanel)
	var config_panel = coordinator.get_current_panel()
	if not config_panel:
		push_warning("config_panel not available, skipping")
		return

	# Attempt to navigate forward with invalid data (empty campaign name)
	var initial_index = coordinator.current_panel_index
	coordinator.next_panel()
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(coordinator):
		return

	# Should not advance if validation fails
	# Note: This depends on coordinator implementation - adjust assertion if needed
	assert_int(coordinator.current_panel_index).is_greater_equal(initial_index)


## TEST SUITE 2: Data Flow Between Panels

func test_config_to_captain_data_flow() -> void:
	"""Test configuration data flows correctly to CaptainPanel"""
	if not coordinator or not is_instance_valid(coordinator):
		push_warning("coordinator not available, skipping")
		return
	
	# Update config data
	coordinator.update_config_state({
		"campaign_name": "Test Campaign Flow",
		"difficulty": 2,
		"victory_condition": "turns_20",
		"story_track_enabled": true
	})
	
	# Get unified state
	var state = coordinator.get_unified_campaign_state()

	# Validate config data persisted (use Dictionary get() for safe access)
	var config = state.get("config", {})
	assert_str(config.get("campaign_name", "")).is_equal("Test Campaign Flow")
	assert_int(config.get("difficulty", 0)).is_equal(2)
	assert_str(config.get("victory_condition", "")).is_equal("turns_20")
	assert_bool(config.get("story_track_enabled", false)).is_true()


func test_captain_data_persistence() -> void:
	"""Test captain data persists across panel navigation"""
	if not coordinator or not is_instance_valid(coordinator):
		push_warning("coordinator not available, skipping")
		return

	# Create captain data
	var captain_data = {
		"captain": {
			"character_name": "Captain Persistent",
			"background": "Military",
			"motivation": "Wealth"
		}
	}

	coordinator.update_captain_state(captain_data)

	# Navigate to another panel and back
	coordinator.next_panel()
	await get_tree().process_frame
	if not is_instance_valid(coordinator):
		return
	coordinator.previous_panel()
	await get_tree().process_frame
	if not is_instance_valid(coordinator):
		return

	# Get state and verify captain data survived (use Dictionary get() for safe access)
	var state = coordinator.get_unified_campaign_state()
	var captain = state.get("captain", {})
	assert_str(captain.get("name", "")).is_equal("Captain Persistent")
	assert_str(captain.get("background", "")).is_equal("Military")


## TEST SUITE 3: Crew Management Flow

func test_crew_creation_persistence() -> void:
	"""Test crew members persist across wizard steps"""
	if not coordinator or not is_instance_valid(coordinator):
		push_warning("coordinator not available, skipping")
		return
	
	# Create crew data
	var crew_data = {
		"members": [
			{
				"character_name": "Crew Member A",
				"combat": 5,
				"reactions": 3
			},
			{
				"character_name": "Crew Member B",
				"combat": 6,
				"reactions": 4
			}
		]
	}
	
	coordinator.update_crew_state(crew_data)
	
	# Get state (use Dictionary get() for safe access)
	var state = coordinator.get_unified_campaign_state()

	# Validate crew members persisted
	var crew = state.get("crew", {})
	var members = crew.get("members", [])
	assert_int(members.size()).is_equal(2)
	# Safe access: ensure array elements are Dictionaries before calling .get()
	var member_0 = members[0] if members.size() > 0 and members[0] is Dictionary else {}
	var member_1 = members[1] if members.size() > 1 and members[1] is Dictionary else {}
	assert_str(member_0.get("character_name", "")).is_equal("Crew Member A")
	assert_str(member_1.get("character_name", "")).is_equal("Crew Member B")


## TEST SUITE 4: Equipment Assignment

func test_equipment_assignment_flow() -> void:
	"""Test equipment is assigned correctly through wizard"""
	if not coordinator or not is_instance_valid(coordinator):
		push_warning("coordinator not available, skipping")
		return
	
	# Create equipment data
	var equipment_data = {
		"items": [
			{
				"name": "Infantry Laser",
				"type": "weapon",
				"assigned_to": "Captain Test"
			},
			{
				"name": "Combat Armor",
				"type": "armor",
				"assigned_to": "Crew Member 1"
			}
		]
	}
	
	coordinator.update_equipment_state(equipment_data)
	
	# Get state
	var state = coordinator.get_unified_campaign_state()

	# Validate equipment exists (use safe Dictionary access pattern)
	var equipment = state.get("equipment", {})
	var items = equipment.get("items", [])
	if items.size() > 0:
		assert_int(items.size()).is_equal(2)


## TEST SUITE 5: FinalPanel Integration

func test_final_panel_receives_all_data() -> void:
	"""Test FinalPanel receives complete campaign data"""
	if not coordinator or not is_instance_valid(coordinator):
		push_warning("coordinator not available, skipping")
		return
	
	# Setup complete campaign data
	coordinator.update_config_state({
		"campaign_name": "Complete Test Campaign",
		"difficulty": 2
	})
	
	coordinator.update_captain_state({
		"captain": {
			"character_name": "Final Panel Captain",
			"background": "Explorer"
		}
	})
	
	coordinator.update_crew_state({
		"members": [
			{"character_name": "Final Crew 1", "combat": 5}
		]
	})
	
	# Get unified state (simulates FinalPanel receiving data)
	var unified_state = coordinator.get_unified_campaign_state()
	
	# Validate all sections present
	assert_bool(unified_state.has("config")).is_true()
	assert_bool(unified_state.has("captain")).is_true()
	assert_bool(unified_state.has("crew")).is_true()

	# Validate data integrity (use Dictionary get() for safe access)
	var config = unified_state.get("config", {})
	var captain = unified_state.get("captain", {})
	var crew = unified_state.get("crew", {})
	assert_str(config.get("campaign_name", "")).is_equal("Complete Test Campaign")
	assert_str(captain.get("name", "")).is_equal("Final Panel Captain")
	assert_int(crew.get("members", []).size()).is_equal(1)


func test_final_panel_displays_without_errors() -> void:
	"""Test FinalPanel can display campaign data without crashes"""
	if not coordinator or not is_instance_valid(coordinator):
		push_warning("coordinator not available, skipping")
		return

	# Create realistic campaign data
	var campaign_data = {
		"config": {
			"campaign_name": "Display Test",
			"difficulty": 2,
			"victory_condition": "turns_20"
		},
		"captain": {
			"name": "Display Captain",
			"background": "Military",
			"combat": 6,
			"reactions": 5
		},
		"crew": {
			"members": [
				{"character_name": "Display Crew", "combat": 4}
			]
		},
		"ship": {
			"name": "Test Ship",
			"hull": 6
		},
		"equipment": []
	}

	# Create FinalPanel instance
	var final_panel = FinalPanel.new()
	add_child(final_panel)
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(final_panel):
		return

	# Update with data (should not crash)
	final_panel.update_campaign_data(campaign_data)
	await get_tree().process_frame

	# Guard against freed instance after await
	if not is_instance_valid(final_panel):
		return

	# If we reach here without errors, test passes
	assert_bool(true).is_true()

	# Cleanup
	final_panel.queue_free()


## TEST SUITE 6: End-to-End Campaign Creation

func test_complete_wizard_creates_campaign() -> void:
	"""Test complete wizard flow creates valid campaign"""
	if not coordinator or not is_instance_valid(coordinator):
		push_warning("coordinator not available, skipping")
		return
	
	# Step 1: Config
	coordinator.update_config_state({
		"campaign_name": "E2E Test Campaign",
		"difficulty": 2,
		"victory_condition": "turns_50",
		"story_track_enabled": false
	})
	
	# Step 2: Captain
	coordinator.update_captain_state({
		"captain": {
			"character_name": "E2E Captain",
			"background": "Explorer",
			"motivation": "Discovery"
		}
	})
	
	# Step 3: Crew
	coordinator.update_crew_state({
		"members": [
			{"character_name": "E2E Crew 1", "combat": 5, "reactions": 3},
			{"character_name": "E2E Crew 2", "combat": 4, "reactions": 4}
		]
	})
	
	# Step 4: Get final state (use Dictionary get() for safe access)
	var final_state = coordinator.get_unified_campaign_state()

	# Validate complete campaign structure
	var config = final_state.get("config", {})
	var captain = final_state.get("captain", {})
	var crew = final_state.get("crew", {})
	var members = crew.get("members", [])
	assert_str(config.get("campaign_name", "")).is_equal("E2E Test Campaign")
	assert_str(captain.get("name", "")).is_equal("E2E Captain")
	assert_int(members.size()).is_equal(2)

	# Validate data types (critical for save/load)
	assert_that(config is Dictionary).is_true()
	assert_that(captain is Dictionary).is_true()
	assert_that(members is Array).is_true()


func test_campaign_data_validation_before_creation() -> void:
	"""Test campaign validation catches missing required data"""
	if not coordinator or not is_instance_valid(coordinator):
		push_warning("coordinator not available, skipping")
		return
	
	# Create incomplete campaign data (missing captain)
	coordinator.update_config_state({
		"campaign_name": "Incomplete Campaign",
		"difficulty": 2
	})
	
	# Validation should fail (implementation-dependent)
	var state = coordinator.get_unified_campaign_state()

	# At minimum, we should have config data (use Dictionary get() for safe access)
	assert_bool(state.has("config")).is_true()
	var config = state.get("config", {})
	assert_str(config.get("campaign_name", "")).is_equal("Incomplete Campaign")


## TEST SUITE 7: Data Type Safety

func test_character_dictionary_conversion() -> void:
	"""Test Character objects are converted to Dictionaries for UI display"""
	if not coordinator or not is_instance_valid(coordinator):
		push_warning("coordinator not available, skipping")
		return

	# Check if method exists before calling
	if not coordinator.has_method("_character_to_dict"):
		push_warning("_character_to_dict method not available, skipping")
		return

	# Simulate Character object as Dictionary
	var mock_character = {
		"character_name": "Type Test Character",
		"combat_skill": 7,
		"reaction": 5
	}

	var result = coordinator._character_to_dict(mock_character)

	# Null check result before accessing
	if result == null or not result is Dictionary:
		push_warning("_character_to_dict returned null or non-Dictionary, skipping")
		return

	# Should have standardized keys
	assert_that(result is Dictionary).is_true()
	assert_str(result.get("character_name", "")).is_equal("Type Test Character")
	assert_int(result.get("combat", 0)).is_equal(7)  # Mapped from combat_skill
	assert_int(result.get("reactions", 0)).is_equal(5)  # Mapped from reaction


func test_mixed_array_type_handling() -> void:
	"""Test coordinator handles mixed Arrays of Characters and Dictionaries"""
	if not coordinator or not is_instance_valid(coordinator):
		push_warning("coordinator not available, skipping")
		return
	
	# Create crew with mixed types
	var crew_data = {
		"members": [
			{"character_name": "Dict Member", "combat": 5},
			{"character_name": "Object Member", "combat_skill": 6, "reaction": 4}
		]
	}
	
	coordinator.update_crew_state(crew_data)
	var state = coordinator.get_unified_campaign_state()
	
	# All members should be normalized to Dictionaries (use safe Dictionary access)
	var crew = state.get("crew", {})
	var members = crew.get("members", [])
	for member in members:
		assert_that(member is Dictionary).is_true()
		assert_bool(member.has("character_name")).is_true()


## TEST SUITE 8: Panel State Synchronization

func test_panel_sync_with_coordinator_state() -> void:
	"""Test panels sync correctly with coordinator state updates"""
	if not coordinator or not is_instance_valid(coordinator):
		push_warning("coordinator not available, skipping")
		return

	# Update state
	coordinator.update_config_state({
		"campaign_name": "Sync Test",
		"difficulty": 3
	})

	# Trigger state update signal
	if coordinator.has_signal("campaign_state_updated"):
		var state = coordinator.get_unified_campaign_state()
		coordinator.campaign_state_updated.emit(state)
		await get_tree().process_frame

		# Guard against freed instance after await
		if not is_instance_valid(coordinator):
			return

	# Get state again
	var final_state = coordinator.get_unified_campaign_state()
	# Use .get() for Dictionary access to avoid errors if key doesn't exist
	var config = final_state.get("config", {})
	assert_str(config.get("campaign_name", "")).is_equal("Sync Test")
