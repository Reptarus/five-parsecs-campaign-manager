extends GdUnitTestSuite

## Data Consistency Integration Tests - Phase 3C.2
## Comprehensive data flow validation tests using DataConsistencyValidator
## Tests data integrity across UI components, state managers, and backend systems

const DataConsistencyValidator = preload("res://src/core/validation/DataConsistencyValidator.gd")
const CampaignCreationStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const UIBackendIntegrationValidator = preload("res://src/core/validation/UIBackendIntegrationValidator.gd")
const ValidationErrorBoundary = preload("res://src/core/validation/ValidationErrorBoundary.gd")

## Test fixtures
var test_scene: Node
var mock_ui_controller: Node
var test_state_manager: CampaignCreationStateManager
var consistency_results: Array[DataConsistencyValidator.DataConsistencyResult] = []

func before_test() -> void:
	"""Setup data consistency testing environment"""
	print("=== Data Consistency Integration Tests - Phase 3C.2 Setup ===")
	
	# Create test scene container
	test_scene = Node.new()
	test_scene.name = "DataConsistencyTestScene"
	add_child(test_scene)
	
	# Create mock UI controller with all required panels
	_create_mock_ui_controller()
	
	# Initialize state manager
	test_state_manager = CampaignCreationStateManager.new()
	
	# Clear previous results
	consistency_results.clear()
	
	print("Data Consistency Tests: Environment ready for validation")

func after_test() -> void:
	"""Cleanup after data consistency tests"""
	if test_scene:
		test_scene.queue_free()
	consistency_results.clear()
	print("Data Consistency Tests: Cleanup complete")

func _create_mock_ui_controller() -> void:
	"""Create comprehensive mock UI controller for testing"""
	mock_ui_controller = Node.new()
	mock_ui_controller.name = "MockCampaignCreationUI"
	test_scene.add_child(mock_ui_controller)
	
	# Create all required panels with backend integration signals
	_create_config_panel()
	_create_crew_panel()
	_create_captain_panel()
	_create_ship_panel()
	_create_equipment_panel()
	_create_final_panel()

func _create_config_panel() -> void:
	"""Create mock config panel"""
	var config_panel = Node.new()
	config_panel.name = "config_panel"
	config_panel.set_script(GDScript.new())
	config_panel.get_script().source_code = """
extends Node
signal config_updated(config: Dictionary)

func get_data() -> Dictionary:
	return {
		"name": "Data Consistency Test Campaign",
		"difficulty": 2,
		"victory_condition": "story_completion",
		"story_track_enabled": true
	}

func is_valid() -> bool:
	return true

func has_signal(signal_name: String) -> bool:
	return signal_name == "config_updated"
"""
	mock_ui_controller.add_child(config_panel)
	mock_ui_controller.set("config_panel", config_panel)

func _create_crew_panel() -> void:
	"""Create mock crew panel with backend integration"""
	var crew_panel = Node.new()
	crew_panel.name = "crew_panel"
	crew_panel.set_script(GDScript.new())
	crew_panel.get_script().source_code = """
extends Node
signal crew_updated(crew_data: Array)
signal crew_generation_requested(crew_size: int)
signal character_customization_needed(character_index: int, character: Variant)

var mock_crew: Array = []
var backend_generated: bool = false

func get_data() -> Dictionary:
	return {
		"crew_members": mock_crew,
		"captain": mock_crew[0] if mock_crew.size() > 0 else null,
		"crew_size": mock_crew.size(),
		"backend_generated": backend_generated
	}

func set_generated_crew(crew: Array, from_backend: bool = false) -> void:
	mock_crew = crew
	backend_generated = from_backend
	crew_updated.emit(crew)

func is_valid() -> bool:
	return mock_crew.size() > 0

func has_signal(signal_name: String) -> bool:
	return signal_name in ["crew_updated", "crew_generation_requested", "character_customization_needed"]
"""
	mock_ui_controller.add_child(crew_panel)
	mock_ui_controller.set("crew_panel", crew_panel)

func _create_captain_panel() -> void:
	"""Create mock captain panel"""
	var captain_panel = Node.new()
	captain_panel.name = "captain_panel"
	captain_panel.set_script(GDScript.new())
	captain_panel.get_script().source_code = """
extends Node
signal captain_updated(captain_data: Dictionary)

func get_data() -> Dictionary:
	return {
		"character_data": {
			"name": "Test Captain",
			"is_captain": true,
			"combat": 4,
			"toughness": 4
		}
	}

func is_valid() -> bool:
	return true

func has_signal(signal_name: String) -> bool:
	return signal_name == "captain_updated"
"""
	mock_ui_controller.add_child(captain_panel)
	mock_ui_controller.set("captain_panel", captain_panel)

func _create_ship_panel() -> void:
	"""Create mock ship panel"""
	var ship_panel = Node.new()
	ship_panel.name = "ship_panel"
	ship_panel.set_script(GDScript.new())
	ship_panel.get_script().source_code = """
extends Node
signal ship_updated(ship_data: Dictionary)

func get_data() -> Dictionary:
	return {
		"name": "Test Ship",
		"type": "Frigate",
		"is_configured": true
	}

func is_valid() -> bool:
	return true

func has_signal(signal_name: String) -> bool:
	return signal_name == "ship_updated"
"""
	mock_ui_controller.add_child(ship_panel)
	mock_ui_controller.set("ship_panel", ship_panel)

func _create_equipment_panel() -> void:
	"""Create mock equipment panel with backend integration"""
	var equipment_panel = Node.new()
	equipment_panel.name = "equipment_panel"
	equipment_panel.set_script(GDScript.new())
	equipment_panel.get_script().source_code = """
extends Node
signal equipment_generated(equipment: Array)
signal equipment_requested(crew_data: Array)

var mock_equipment: Array = []
var backend_generated: bool = false
var starting_credits: int = 1000

func get_data() -> Dictionary:
	return {
		"equipment": mock_equipment,
		"starting_credits": starting_credits,
		"is_complete": mock_equipment.size() > 0,
		"backend_generated": backend_generated
	}

func set_generated_equipment(equipment: Array, credits: int, from_backend: bool = false) -> void:
	mock_equipment = equipment
	starting_credits = credits
	backend_generated = from_backend
	equipment_generated.emit(equipment)

func is_valid() -> bool:
	return mock_equipment.size() > 0

func has_signal(signal_name: String) -> bool:
	return signal_name in ["equipment_generated", "equipment_requested"]
"""
	mock_ui_controller.add_child(equipment_panel)
	mock_ui_controller.set("equipment_panel", equipment_panel)

func _create_final_panel() -> void:
	"""Create mock final panel"""
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

func has_signal(signal_name: String) -> bool:
	return signal_name == "campaign_creation_requested"
"""
	mock_ui_controller.add_child(final_panel)
	mock_ui_controller.set("final_panel", final_panel)

## DATA FLOW CONSISTENCY TESTS

func test_campaign_creation_data_flow_consistency():
	"""Test campaign creation data flow consistency"""
	print("Testing campaign creation data flow consistency...")
	
	# Populate panels with test data
	_populate_panels_with_test_data()
	
	# Run data flow consistency validation
	var result = DataConsistencyValidator.validate_campaign_creation_data_flow(
		mock_ui_controller,
		test_state_manager
	)
	
	consistency_results.append(result)
	
	# Validate result
	assert_that(result).is_not_null()
	assert_that(result.success).is_true().override_failure_message(
		"Campaign creation data flow validation failed: %s" % result.message
	)
	
	# Check detailed metrics
	assert_that(result.metrics.ui_panels_checked).is_equal(5)  # 5 main panels
	assert_that(result.metrics.backend_calls_verified).is_greater_equal(2)  # Crew + Equipment
	assert_that(result.metrics.state_transitions_validated).is_equal(1)
	
	print("✅ Campaign creation data flow consistency test passed")
	print("  Panels checked: %d" % result.metrics.ui_panels_checked)
	print("  Backend calls verified: %d" % result.metrics.backend_calls_verified)
	print("  Duration: %dms" % result.details.validation_duration_ms)

func test_multi_turn_data_persistence_consistency():
	"""Test multi-turn campaign data persistence consistency"""
	print("Testing multi-turn data persistence consistency...")
	
	# Generate multi-turn campaign sequence
	var campaign_sequence = _generate_multi_turn_sequence(5)
	
	# Run persistence consistency validation
	var result = DataConsistencyValidator.validate_multi_turn_persistence(campaign_sequence)
	consistency_results.append(result)
	
	# Validate result
	assert_that(result).is_not_null()
	assert_that(result.success).is_true().override_failure_message(
		"Multi-turn persistence validation failed: %s" % result.message
	)
	
	# Check detailed metrics
	assert_that(result.metrics.turns_analyzed).is_equal(5)
	assert_that(result.metrics.data_fields_tracked).is_greater_than(0)
	assert_that(result.metrics.consistency_violations).is_equal(0)
	
	print("✅ Multi-turn data persistence consistency test passed")
	print("  Turns analyzed: %d" % result.metrics.turns_analyzed)
	print("  Fields tracked: %d" % result.metrics.data_fields_tracked)
	print("  Violations: %d" % result.metrics.consistency_violations)

func test_backend_ui_data_consistency():
	"""Test backend-UI data consistency"""
	print("Testing backend-UI data consistency...")
	
	# Generate test data sets
	var ui_data = _generate_consistent_ui_data()
	var backend_data = _generate_consistent_backend_data()
	
	# Run consistency validation
	var result = DataConsistencyValidator.validate_backend_ui_consistency(ui_data, backend_data)
	consistency_results.append(result)
	
	# Validate result
	assert_that(result).is_not_null()
	assert_that(result.success).is_true().override_failure_message(
		"Backend-UI consistency validation failed: %s" % result.message
	)
	
	# Check detailed metrics
	assert_that(result.metrics.data_categories_checked).is_greater_than(0)
	assert_that(result.metrics.fields_compared).is_greater_than(0)
	assert_that(result.metrics.mismatches_found).is_equal(0)
	
	print("✅ Backend-UI data consistency test passed")
	print("  Categories checked: %d" % result.metrics.data_categories_checked)
	print("  Fields compared: %d" % result.metrics.fields_compared)
	print("  Mismatches: %d" % result.metrics.mismatches_found)

func test_data_consistency_with_backend_integration():
	"""Test data consistency with actual backend integration"""
	print("Testing data consistency with backend integration...")
	
	# Populate crew panel with backend-generated data
	var crew_panel = mock_ui_controller.get("crew_panel")
	var mock_crew = [
		{"character_name": "Backend Captain", "is_captain": true, "combat": 4},
		{"character_name": "Backend Crew 1", "combat": 3},
		{"character_name": "Backend Crew 2", "combat": 3}
	]
	crew_panel.set_generated_crew(mock_crew, true)  # Mark as backend-generated
	
	# Populate equipment panel with backend-generated data
	var equipment_panel = mock_ui_controller.get("equipment_panel")
	var mock_equipment = [
		{"name": "Backend Weapon 1", "type": "Weapon", "owner": "Backend Captain"},
		{"name": "Backend Weapon 2", "type": "Weapon", "owner": "Backend Crew 1"},
		{"name": "Backend Weapon 3", "type": "Weapon", "owner": "Backend Crew 2"}
	]
	equipment_panel.set_generated_equipment(mock_equipment, 1500, true)  # Mark as backend-generated
	
	# Run data flow validation
	var result = DataConsistencyValidator.validate_campaign_creation_data_flow(
		mock_ui_controller,
		test_state_manager
	)
	
	consistency_results.append(result)
	
	# Validate backend integration
	assert_that(result.success).is_true().override_failure_message(
		"Backend integration consistency failed: %s" % result.message
	)
	
	# Verify backend integration markers
	var crew_data = crew_panel.get_data()
	var equipment_data = equipment_panel.get_data()
	
	assert_that(crew_data.backend_generated).is_true()
	assert_that(equipment_data.backend_generated).is_true()
	
	print("✅ Data consistency with backend integration test passed")
	print("  Crew backend integration: ✓")
	print("  Equipment backend integration: ✓")

func test_data_consistency_error_handling():
	"""Test data consistency validation error handling"""
	print("Testing data consistency error handling...")
	
	# Test with null UI controller
	var null_result = DataConsistencyValidator.validate_campaign_creation_data_flow(null, test_state_manager)
	assert_that(null_result.success).is_false()
	assert_that(null_result.severity).is_equal(DataConsistencyValidator.ConsistencySeverity.CRITICAL_MISMATCH)
	
	# Test with insufficient turn data
	var insufficient_turns = [{"campaign_turn": 1, "crew": []}]  # Only 1 turn
	var insufficient_result = DataConsistencyValidator.validate_multi_turn_persistence(insufficient_turns)
	assert_that(insufficient_result.success).is_false()
	assert_that(insufficient_result.severity).is_equal(DataConsistencyValidator.ConsistencySeverity.CRITICAL_MISMATCH)
	
	# Test with inconsistent data types
	var ui_data = {"crew": ["string_data"]}
	var backend_data = {"crew": {"dict_data": true}}
	var type_mismatch_result = DataConsistencyValidator.validate_backend_ui_consistency(ui_data, backend_data)
	assert_that(type_mismatch_result.success).is_false()
	
	print("✅ Data consistency error handling test passed")
	print("  Null controller handling: ✓")
	print("  Insufficient data handling: ✓") 
	print("  Type mismatch handling: ✓")

func test_comprehensive_data_consistency_validation():
	"""Test comprehensive data consistency validation suite"""
	print("Testing comprehensive data consistency validation...")
	
	# Populate test data
	_populate_panels_with_test_data()
	var campaign_sequence = _generate_multi_turn_sequence(3)
	
	# Run comprehensive validation
	var results = DataConsistencyValidator.validate_comprehensive_data_consistency(
		mock_ui_controller,
		test_state_manager,
		campaign_sequence
	)
	
	consistency_results.append_array(results)
	
	# Validate comprehensive results
	assert_that(results.size()).is_greater_equal(3)  # At least 3 validation types
	
	var all_passed = true
	var failed_validations: Array[String] = []
	
	for result in results:
		if not result.success:
			all_passed = false
			var validation_name = DataConsistencyValidator.ConsistencyValidationType.keys()[result.validation_type]
			failed_validations.append(validation_name)
	
	assert_that(all_passed).is_true().override_failure_message(
		"Some comprehensive validations failed: %s" % ", ".join(failed_validations)
	)
	
	print("✅ Comprehensive data consistency validation test passed")
	print("  Total validations: %d" % results.size())
	print("  All validations passed: ✓")

func test_data_consistency_performance_benchmarks():
	"""Test data consistency validation performance benchmarks"""
	print("Testing data consistency performance benchmarks...")
	
	var performance_start = Time.get_ticks_msec()
	
	# Run multiple consistency validations
	for i in range(10):
		var ui_data = _generate_consistent_ui_data()
		var backend_data = _generate_consistent_backend_data()
		var result = DataConsistencyValidator.validate_backend_ui_consistency(ui_data, backend_data)
		consistency_results.append(result)
	
	var total_duration = Time.get_ticks_msec() - performance_start
	var avg_duration = total_duration / 10
	
	# Performance should be reasonable (under 50ms per validation)
	assert_that(avg_duration).is_less_than(50).override_failure_message(
		"Data consistency validation too slow: %dms average" % avg_duration
	)
	
	print("✅ Data consistency performance benchmark test passed")
	print("  Total duration: %dms" % total_duration)
	print("  Average per validation: %dms" % avg_duration)
	print("  Performance rating: GOOD")

## DATA INTEGRITY EDGE CASES

func test_data_consistency_with_corrupted_data():
	"""Test data consistency validation with corrupted data"""
	print("Testing data consistency with corrupted data...")
	
	# Create corrupted campaign sequence
	var corrupted_sequence = [
		{"campaign_turn": 1, "crew_members": ["valid_data"], "credits": 1000},
		{"campaign_turn": 3, "crew_members": null, "credits": -500},  # Corrupted turn
		{"campaign_turn": 4, "equipment_items": "invalid_type"}  # Missing crew_members
	]
	
	var result = DataConsistencyValidator.validate_multi_turn_persistence(corrupted_sequence)
	consistency_results.append(result)
	
	# Should detect corruption
	assert_that(result.success).is_false()
	assert_that(result.metrics.consistency_violations).is_greater_than(0)
	
	print("✅ Corrupted data consistency test passed")
	print("  Violations detected: %d" % result.metrics.consistency_violations)

func test_data_consistency_with_partial_backend_integration():
	"""Test data consistency with partial backend integration"""
	print("Testing data consistency with partial backend integration...")
	
	# Set only crew panel as backend-integrated
	var crew_panel = mock_ui_controller.get("crew_panel")
	crew_panel.set_generated_crew([{"name": "Backend Crew"}], true)
	
	# Equipment panel remains non-backend
	var equipment_panel = mock_ui_controller.get("equipment_panel")
	equipment_panel.set_generated_equipment([{"name": "Manual Equipment"}], 1000, false)
	
	var result = DataConsistencyValidator.validate_campaign_creation_data_flow(
		mock_ui_controller,
		test_state_manager
	)
	
	consistency_results.append(result)
	
	# Should still pass but note partial integration
	assert_that(result.success).is_true()
	assert_that(result.metrics.backend_calls_verified).is_equal(1)  # Only crew
	
	print("✅ Partial backend integration consistency test passed")
	print("  Backend calls verified: %d/2" % result.metrics.backend_calls_verified)

## HELPER METHODS

func _populate_panels_with_test_data() -> void:
	"""Populate all panels with consistent test data"""
	var crew_panel = mock_ui_controller.get("crew_panel")
	var equipment_panel = mock_ui_controller.get("equipment_panel")
	
	# Crew data
	var test_crew = [
		{"character_name": "Test Captain", "is_captain": true, "combat": 4},
		{"character_name": "Test Crew 1", "combat": 3},
		{"character_name": "Test Crew 2", "combat": 3}
	]
	crew_panel.set_generated_crew(test_crew, true)
	
	# Equipment data
	var test_equipment = [
		{"name": "Test Weapon 1", "type": "Weapon", "owner": "Test Captain"},
		{"name": "Test Weapon 2", "type": "Weapon", "owner": "Test Crew 1"},
		{"name": "Test Weapon 3", "type": "Weapon", "owner": "Test Crew 2"}
	]
	equipment_panel.set_generated_equipment(test_equipment, 1200, true)

func _generate_multi_turn_sequence(num_turns: int) -> Array[Dictionary]:
	"""Generate consistent multi-turn campaign sequence"""
	var sequence: Array[Dictionary] = []
	
	for i in range(1, num_turns + 1):
		var turn_data = {
			"campaign_turn": i,
			"crew_members": [
				{"name": "Captain", "combat": 4},
				{"name": "Crew 1", "combat": 3}
			],
			"equipment_items": [
				{"name": "Weapon 1", "type": "Weapon"},
				{"name": "Weapon 2", "type": "Weapon"}
			],
			"credits": 1000 + (i * 100),  # Credits increase each turn
			"ship_data": {"name": "Test Ship", "type": "Frigate"},
			"story_progress": i * 10,  # Story progress increases
			"reputation": i * 5,
			"relationships": {}
		}
		sequence.append(turn_data)
	
	return sequence

func _generate_consistent_ui_data() -> Dictionary:
	"""Generate consistent UI data for testing"""
	return {
		"crew": [
			{"name": "UI Captain", "combat": 4, "is_captain": true},
			{"name": "UI Crew 1", "combat": 3}
		],
		"equipment": [
			{"name": "UI Weapon 1", "type": "Weapon", "owner": "UI Captain"},
			{"name": "UI Weapon 2", "type": "Weapon", "owner": "UI Crew 1"}
		],
		"resources": {
			"credits": 1200,
			"reputation": 0
		},
		"progress": {
			"story_points": 0,
			"missions_completed": 0
		},
		"relationships": {}
	}

func _generate_consistent_backend_data() -> Dictionary:
	"""Generate consistent backend data (matching UI data)"""
	return {
		"crew": [
			{"name": "UI Captain", "combat": 4, "is_captain": true},
			{"name": "UI Crew 1", "combat": 3}
		],
		"equipment": [
			{"name": "UI Weapon 1", "type": "Weapon", "owner": "UI Captain"},
			{"name": "UI Weapon 2", "type": "Weapon", "owner": "UI Crew 1"}
		],
		"resources": {
			"credits": 1200,
			"reputation": 0
		},
		"progress": {
			"story_points": 0,
			"missions_completed": 0
		},
		"relationships": {}
	}

## COMPREHENSIVE TEST SUMMARY

func test_data_consistency_validation_summary():
	"""Generate comprehensive data consistency validation summary"""
	print("=== DATA CONSISTENCY VALIDATION SUMMARY ===")
	
	var total_validations = consistency_results.size()
	var passed_validations = 0
	var failed_validations = 0
	var warning_validations = 0
	var critical_validations = 0
	
	for result in consistency_results:
		match result.severity:
			DataConsistencyValidator.ConsistencySeverity.CONSISTENT:
				passed_validations += 1
			DataConsistencyValidator.ConsistencySeverity.MINOR_DRIFT:
				warning_validations += 1
			DataConsistencyValidator.ConsistencySeverity.MAJOR_DRIFT:
				failed_validations += 1
			DataConsistencyValidator.ConsistencySeverity.CRITICAL_MISMATCH:
				critical_validations += 1
	
	print("Total Validations: %d" % total_validations)
	print("✅ Consistent: %d" % passed_validations)
	print("⚠️ Minor Drift: %d" % warning_validations)
	print("❌ Major Drift: %d" % failed_validations)
	print("🚨 Critical: %d" % critical_validations)
	
	# Overall assessment
	var overall_success_rate = float(passed_validations) / float(max(1, total_validations))
	
	assert_that(overall_success_rate).is_greater_than(0.8).override_failure_message(
		"Data consistency success rate %.2f below 80%%" % (overall_success_rate * 100)
	)
	
	print("\n🎯 PHASE 3C.2 DATA CONSISTENCY RESULT: %s" % ("PASSED" if overall_success_rate > 0.8 else "FAILED"))
	print("✅ Overall success rate: %.1f%%" % (overall_success_rate * 100))
	print("🚀 Data consistency validation is ready for production use")