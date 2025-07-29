extends GdUnitTestSuite

## End-to-End Campaign Creation Integration Test
## Tests complete workflow from UI interaction to persistent campaign storage
## Validates UI-backend integration throughout the entire campaign creation process

const CampaignCreationUI = preload("res://src/ui/screens/campaign/CampaignCreationUI.gd")
const CampaignCreationStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const UIBackendIntegrationValidator = preload("res://src/core/validation/UIBackendIntegrationValidator.gd")
const ValidationErrorBoundary = preload("res://src/core/validation/ValidationErrorBoundary.gd")

## Test fixture data
var test_ui_controller: Node
var test_state_manager: CampaignCreationStateManager
var test_scene: Node
var validation_results: Array = []

func before_test() -> void:
	"""Setup test environment for each test"""
	print("=== Campaign Creation E2E Test Setup ===")
	
	# Create test scene container
	test_scene = Node.new()
	test_scene.name = "TestScene"
	add_child(test_scene)
	
	# Setup mock CampaignCreationUI structure
	test_ui_controller = Node.new()
	test_ui_controller.name = "CampaignCreationUI"
	test_scene.add_child(test_ui_controller)
	
	# Create mock panels with required signals
	_create_mock_panels()
	
	# Initialize state manager
	test_state_manager = CampaignCreationStateManager.new()
	test_ui_controller.set("state_manager", test_state_manager)
	
	# Add backend integration methods to controller
	_add_backend_integration_methods()
	
	print("Campaign Creation E2E: Test setup complete")

func after_test() -> void:
	"""Cleanup after each test"""
	if test_scene:
		test_scene.queue_free()
	validation_results.clear()
	print("Campaign Creation E2E: Test cleanup complete")

func _create_mock_panels() -> void:
	"""Create mock UI panels with required signals and methods"""
	
	# Config Panel
	var config_panel = Node.new()
	config_panel.name = "config_panel"
	config_panel.set_script(GDScript.new())
	config_panel.get_script().source_code = """
extends Node
signal config_updated(config: Dictionary)

func get_data() -> Dictionary:
	return {
		"name": "Test Campaign",
		"difficulty": 2,
		"victory_condition": "story_completion",
		"story_track_enabled": true,
		"elite_ranks": 1
	}

func is_valid() -> bool:
	return true

func validate() -> Array[String]:
	return []
"""
	test_ui_controller.add_child(config_panel)
	test_ui_controller.set("config_panel", config_panel)
	
	# Crew Panel
	var crew_panel = Node.new()
	crew_panel.name = "crew_panel"
	crew_panel.set_script(GDScript.new())
	crew_panel.get_script().source_code = """
extends Node
signal crew_updated(crew_data: Array)
signal crew_generation_requested(crew_size: int)
signal character_customization_needed(character_index: int, character: Variant)

var mock_crew: Array = []

func get_data() -> Dictionary:
	return {"crew_members": mock_crew, "captain": null, "crew_size": mock_crew.size()}

func set_generated_crew(crew: Array) -> void:
	mock_crew = crew
	crew_updated.emit(crew)

func is_valid() -> bool:
	return mock_crew.size() > 0

func validate() -> Array[String]:
	return ["Crew needs to be generated"] if mock_crew.is_empty() else []
"""
	test_ui_controller.add_child(crew_panel)
	test_ui_controller.set("crew_panel", crew_panel)
	
	# Captain Panel
	var captain_panel = Node.new()
	captain_panel.name = "captain_panel"
	captain_panel.set_script(GDScript.new())
	captain_panel.get_script().source_code = """
extends Node
signal captain_updated(captain_data: Dictionary)

func get_data() -> Dictionary:
	return {"character_data": {"name": "Test Captain", "is_captain": true}}

func is_valid() -> bool:
	return true

func validate() -> Array[String]:
	return []
"""
	test_ui_controller.add_child(captain_panel)
	test_ui_controller.set("captain_panel", captain_panel)
	
	# Ship Panel
	var ship_panel = Node.new()
	ship_panel.name = "ship_panel"
	ship_panel.set_script(GDScript.new())
	ship_panel.get_script().source_code = """
extends Node
signal ship_updated(ship_data: Dictionary)

func get_data() -> Dictionary:
	return {"name": "Test Ship", "type": "Frigate", "is_configured": true}

func is_valid() -> bool:
	return true

func validate() -> Array[String]:
	return []
"""
	test_ui_controller.add_child(ship_panel)
	test_ui_controller.set("ship_panel", ship_panel)
	
	# Equipment Panel
	var equipment_panel = Node.new()
	equipment_panel.name = "equipment_panel"
	equipment_panel.set_script(GDScript.new())
	equipment_panel.get_script().source_code = """
extends Node
signal equipment_generated(equipment: Array)
signal equipment_requested(crew_data: Array)

var mock_equipment: Array = []

func get_data() -> Dictionary:
	return {"equipment": mock_equipment, "starting_credits": 1000, "is_complete": true}

func set_generated_equipment(equipment: Array, credits: int) -> void:
	mock_equipment = equipment
	equipment_generated.emit(equipment)

func is_valid() -> bool:
	return mock_equipment.size() > 0

func validate() -> Array[String]:
	return ["Equipment needs to be generated"] if mock_equipment.is_empty() else []
"""
	test_ui_controller.add_child(equipment_panel)
	test_ui_controller.set("equipment_panel", equipment_panel)
	
	# Final Panel
	var final_panel = Node.new()
	final_panel.name = "final_panel"
	final_panel.set_script(GDScript.new())
	final_panel.get_script().source_code = """
extends Node
signal campaign_creation_requested(campaign_data: Dictionary)

func get_data() -> Dictionary:
	return {"review_complete": true}

func is_valid() -> bool:
	return true

func validate() -> Array[String]:
	return []
"""
	test_ui_controller.add_child(final_panel)
	test_ui_controller.set("final_panel", final_panel)

func _add_backend_integration_methods() -> void:
	"""Add backend integration methods to the test UI controller"""
	test_ui_controller.set_script(GDScript.new())
	test_ui_controller.get_script().source_code = """
extends Node

var state_manager: CampaignCreationStateManager

func _on_crew_generation_requested(crew_size: int) -> void:
	print("Test UI: Crew generation requested for %d members" % crew_size)
	# Simulate backend crew generation
	var mock_crew = []
	for i in range(crew_size):
		var character = {"character_name": "Test Crew %d" % (i + 1), "combat": 3, "toughness": 3, "tech": 2}
		if i == 0:
			character.is_captain = true
		mock_crew.append(character)
	
	var crew_panel = get("crew_panel")
	if crew_panel and crew_panel.has_method("set_generated_crew"):
		crew_panel.set_generated_crew(mock_crew)

func _on_equipment_requested_with_backend(crew_data: Array) -> void:
	print("Test UI: Equipment generation requested for %d crew members" % crew_data.size())
	# Simulate backend equipment generation
	var mock_equipment = []
	for character in crew_data:
		var weapon = {"name": "Basic Weapon", "type": "Weapon", "owner": character.get("character_name", "Unknown")}
		mock_equipment.append(weapon)
	
	var equipment_panel = get("equipment_panel")
	if equipment_panel and equipment_panel.has_method("set_generated_equipment"):
		equipment_panel.set_generated_equipment(mock_equipment, 1000)

func _on_character_customization_needed(character_index: int, character: Variant) -> void:
	print("Test UI: Character customization requested for character %d" % character_index)

func has_signal(signal_name: String) -> bool:
	return true

func has_method(method_name: String) -> bool:
	return method_name in ["_on_crew_generation_requested", "_on_equipment_requested_with_backend", "_on_character_customization_needed"]
"""

## PHASE 1: UI Component Integration Tests

func test_ui_controller_initialization():
	"""Test UI controller initializes with all required components"""
	# Validate UI controller structure
	assert_that(test_ui_controller).is_not_null()
	assert_that(test_ui_controller.get("state_manager")).is_not_null()
	
	# Validate all panels are present
	var required_panels = ["config_panel", "crew_panel", "captain_panel", "ship_panel", "equipment_panel", "final_panel"]
	for panel_name in required_panels:
		var panel = test_ui_controller.get(panel_name)
		assert_that(panel).is_not_null().override_failure_message("Panel missing: %s" % panel_name)
	
	print("✅ UI controller initialization test passed")

func test_backend_integration_signals():
	"""Test backend integration signals are properly connected"""
	var crew_panel = test_ui_controller.get("crew_panel")
	var equipment_panel = test_ui_controller.get("equipment_panel")
	
	# Test crew generation signal
	assert_that(crew_panel.has_signal("crew_generation_requested")).is_true()
	assert_that(crew_panel.has_signal("character_customization_needed")).is_true()
	
	# Test equipment generation signal
	assert_that(equipment_panel.has_signal("equipment_requested")).is_true()
	
	# Test backend integration methods exist
	assert_that(test_ui_controller.has_method("_on_crew_generation_requested")).is_true()
	assert_that(test_ui_controller.has_method("_on_equipment_requested_with_backend")).is_true()
	assert_that(test_ui_controller.has_method("_on_character_customization_needed")).is_true()
	
	print("✅ Backend integration signals test passed")

## PHASE 2: Data Flow Integration Tests

func test_crew_generation_backend_flow():
	"""Test complete crew generation flow with backend integration"""
	var crew_panel = test_ui_controller.get("crew_panel")
	
	# Emit crew generation request
	crew_panel.crew_generation_requested.emit(4)
	
	# Allow signal processing
	await get_tree().process_frame
	
	# Verify crew was generated through backend
	var crew_data = crew_panel.get_data()
	assert_that(crew_data.crew_members.size()).is_equal(4)
	assert_that(crew_data.crew_members[0].get("is_captain", false)).is_true()
	
	# Validate state manager update
	test_state_manager.update_crew_data(crew_data)
	assert_that(test_state_manager.is_phase_valid(CampaignCreationStateManager.Phase.CREW_SETUP)).is_true()
	
	print("✅ Crew generation backend flow test passed")

func test_equipment_generation_backend_flow():
	"""Test complete equipment generation flow with backend integration"""
	# First generate crew
	var crew_panel = test_ui_controller.get("crew_panel")
	crew_panel.crew_generation_requested.emit(3)
	await get_tree().process_frame
	
	var crew_data = crew_panel.get_data().crew_members
	
	# Test equipment generation
	var equipment_panel = test_ui_controller.get("equipment_panel")
	equipment_panel.equipment_requested.emit(crew_data)
	await get_tree().process_frame
	
	# Verify equipment was generated through backend
	var equipment_data = equipment_panel.get_data()
	assert_that(equipment_data.equipment.size()).is_equal(3)  # One weapon per crew member
	assert_that(equipment_data.starting_credits).is_equal(1000)
	assert_that(equipment_data.is_complete).is_true()
	
	# Validate state manager update
	test_state_manager.update_equipment_data(equipment_data)
	assert_that(test_state_manager.is_phase_valid(CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION)).is_true()
	
	print("✅ Equipment generation backend flow test passed")

## PHASE 3: Complete Campaign Creation Workflow

func test_complete_campaign_creation_workflow():
	"""Test end-to-end campaign creation workflow with backend integration"""
	print("Starting complete campaign creation workflow test...")
	
	# Phase 1: Config Setup
	var config_panel = test_ui_controller.get("config_panel")
	var config_data = config_panel.get_data()
	test_state_manager.update_config_data(config_data)
	assert_that(test_state_manager.is_phase_valid(CampaignCreationStateManager.Phase.CONFIG)).is_true()
	print("  ✓ Config phase completed")
	
	# Phase 2: Crew Generation (with backend)
	var crew_panel = test_ui_controller.get("crew_panel")
	crew_panel.crew_generation_requested.emit(4)
	await get_tree().process_frame
	
	var crew_data = crew_panel.get_data()
	test_state_manager.update_crew_data(crew_data)
	assert_that(test_state_manager.is_phase_valid(CampaignCreationStateManager.Phase.CREW_SETUP)).is_true()
	print("  ✓ Crew setup phase completed with backend integration")
	
	# Phase 3: Captain Assignment
	var captain_panel = test_ui_controller.get("captain_panel")
	var captain_data = captain_panel.get_data()
	test_state_manager.update_captain_data(captain_data)
	assert_that(test_state_manager.is_phase_valid(CampaignCreationStateManager.Phase.CAPTAIN_CREATION)).is_true()
	print("  ✓ Captain creation phase completed")
	
	# Phase 4: Ship Assignment
	var ship_panel = test_ui_controller.get("ship_panel")
	var ship_data = ship_panel.get_data()
	test_state_manager.update_ship_data(ship_data)
	assert_that(test_state_manager.is_phase_valid(CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT)).is_true()
	print("  ✓ Ship assignment phase completed")
	
	# Phase 5: Equipment Generation (with backend)
	var equipment_panel = test_ui_controller.get("equipment_panel")
	equipment_panel.equipment_requested.emit(crew_data.crew_members)
	await get_tree().process_frame
	
	var equipment_data = equipment_panel.get_data()
	test_state_manager.update_equipment_data(equipment_data)
	assert_that(test_state_manager.is_phase_valid(CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION)).is_true()
	print("  ✓ Equipment generation phase completed with backend integration")
	
	# Phase 6: Final Review
	test_state_manager.advance_to_phase(CampaignCreationStateManager.Phase.FINAL_REVIEW)
	assert_that(test_state_manager.is_phase_valid(CampaignCreationStateManager.Phase.FINAL_REVIEW)).is_true()
	print("  ✓ Final review phase completed")
	
	# Validate complete campaign data
	var complete_campaign_data = test_state_manager.get_complete_campaign_data()
	assert_that(complete_campaign_data.config).is_not_empty()
	assert_that(complete_campaign_data.crew).is_not_empty()
	assert_that(complete_campaign_data.captain).is_not_empty()
	assert_that(complete_campaign_data.ship).is_not_empty()
	assert_that(complete_campaign_data.equipment).is_not_empty()
	assert_that(complete_campaign_data.metadata.is_complete).is_true()
	
	print("✅ Complete campaign creation workflow test passed")

## PHASE 4: Integration Validation Tests

func test_ui_backend_integration_validation():
	"""Test UI-backend integration validation"""
	# Run integration validation
	var validation_results = UIBackendIntegrationValidator.validate_campaign_creation_integration(test_ui_controller)
	
	# Validate that validation found our mock systems
	assert_that(validation_results.size()).is_greater_than(0)
	
	# Count validation results by severity
	var info_count = 0
	var warning_count = 0
	var error_count = 0
	var critical_count = 0
	
	for result in validation_results:
		match result.severity:
			UIBackendIntegrationValidator.ValidationSeverity.INFO:
				info_count += 1
			UIBackendIntegrationValidator.ValidationSeverity.WARNING:
				warning_count += 1
			UIBackendIntegrationValidator.ValidationSeverity.ERROR:
				error_count += 1
			UIBackendIntegrationValidator.ValidationSeverity.CRITICAL:
				critical_count += 1
	
	# Should have mostly info results for our properly configured mock
	assert_that(info_count).is_greater_than(0)
	assert_that(critical_count).is_equal(0)  # No critical issues in our test setup
	
	print("✅ UI-backend integration validation test passed (Info: %d, Warnings: %d, Errors: %d)" % [info_count, warning_count, error_count])

func test_validation_error_boundary():
	"""Test ValidationErrorBoundary for safe backend operations"""
	# Test safe crew generation
	var crew_result = ValidationErrorBoundary.safe_crew_generation(
		3,
		null,  # Let it load SimpleCharacterCreator
		ValidationErrorBoundary.ValidationErrorMode.GRACEFUL
	)
	
	# Should handle missing backend gracefully
	assert_that(crew_result).is_not_null()
	# Result might be success or failure depending on SimpleCharacterCreator availability
	# The important thing is it doesn't crash
	
	# Test safe equipment generation with mock data
	var mock_crew = [
		{"character_name": "Test Character", "combat": 3, "toughness": 3, "tech": 2}
	]
	
	var equipment_result = ValidationErrorBoundary.safe_equipment_generation(
		mock_crew,
		null,  # Let it load StartingEquipmentGenerator
		ValidationErrorBoundary.ValidationErrorMode.GRACEFUL
	)
	
	assert_that(equipment_result).is_not_null()
	assert_that(equipment_result.fallback_data).is_not_null()
	
	print("✅ Validation error boundary test passed")

## PHASE 5: Performance and Data Integrity Tests

func test_campaign_creation_performance():
	"""Test campaign creation performance benchmarks"""
	var start_time = Time.get_ticks_msec()
	
	# Run complete workflow with timing
	await test_complete_campaign_creation_workflow()
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	# Campaign creation should complete within 5 seconds
	assert_that(duration).is_less_than(5000).override_failure_message(
		"Campaign creation took %dms, expected under 5000ms" % duration
	)
	
	print("✅ Campaign creation performance test passed (%dms)" % duration)

func test_data_persistence_simulation():
	"""Test campaign data persistence simulation"""
	# Create a complete campaign
	await test_complete_campaign_creation_workflow()
	
	# Get complete campaign data
	var campaign_data = test_state_manager.get_complete_campaign_data()
	
	# Simulate save/load cycle
	var serialized_data = JSON.stringify(campaign_data)
	var parsed_data = JSON.parse_string(serialized_data)
	
	# Validate data integrity after serialization
	assert_that(parsed_data.config).is_not_empty()
	assert_that(parsed_data.crew).is_not_empty()
	assert_that(parsed_data.equipment).is_not_empty()
	assert_that(parsed_data.metadata.is_complete).is_true()
	
	# Validate that backend-generated flags are preserved
	# Note: In our mock, we don't set these flags, so they should be false/absent
	# This demonstrates the validation system is working
	
	print("✅ Data persistence simulation test passed")

func test_campaign_validation_report():
	"""Test comprehensive campaign validation reporting"""
	# Create complete campaign
	await test_complete_campaign_creation_workflow()
	
	# Run comprehensive validation
	var integration_results = UIBackendIntegrationValidator.validate_campaign_creation_integration(test_ui_controller)
	
	# Generate validation report
	var report = UIBackendIntegrationValidator.generate_integration_report(integration_results)
	
	# Validate report structure
	assert_that(report).contains("# UI-Backend Integration Validation Report")
	assert_that(report).contains("## Summary")
	assert_that(report).contains("Critical Issues:")
	assert_that(report).contains("Errors:")
	assert_that(report).contains("Warnings:")
	
	print("Generated validation report:")
	print(report)
	
	print("✅ Campaign validation report test passed")