@tool
extends "res://tests/fixtures/base/gdunit_game_test.gd"
class_name CampaignTest

# Campaign test configuration
const CAMPAIGN_TEST_CONFIG := {
	"stabilize_time": 0.2 as float,
	"save_timeout": 2.0 as float,
	"load_timeout": 2.0 as float,
	"phase_timeout": 1.0 as float
}

# Campaign test states
var _campaign_system: Node = null
var _campaign_data: Node = null

# Campaign test configuration
const TEST_CAMPAIGN_CONFIG := {
	"difficulty": 0, # Normal difficulty
	"permadeath": true,
	"story_track": true,
	"auto_save": true
}

# Setup methods
func before_test() -> void:
	super.before_test()
	if not await setup_campaign_systems():
		push_error("Failed to setup campaign systems")
		return
	await stabilize_engine()

func after_test() -> void:
	_cleanup_campaign_resources()
	super.after_test()

# Base system setup
func setup_campaign_systems() -> bool:
	if not _setup_campaign_system():
		return false
	return true

func _setup_campaign_system() -> bool:
	_campaign_system = Node.new()
	if not _campaign_system:
		push_error("Failed to create campaign system")
		return false
	_campaign_system.name = "CampaignSystem"
	add_child(_campaign_system)
	track_node(_campaign_system)
	return true

# Resource cleanup
func _cleanup_campaign_resources() -> void:
	_campaign_system = null
	_campaign_data = null

# Required interface implementations
func create_test_campaign(name: String = "Test Campaign") -> Resource:
	var campaign := Resource.new()
	if not campaign:
		push_error("Failed to create campaign resource")
		return null
	track_resource(campaign)
	return campaign

func verify_campaign_state(campaign: Resource, expected_state: Dictionary) -> void:
	if not campaign or not expected_state:
		push_error("Invalid campaign or expected state")
		return
		
	for property in expected_state:
		var actual_value = campaign.get(property) if campaign.has_method("get_" + property) else campaign.get(property)
		var expected_value = expected_state[property]
		assert_that(actual_value).override_failure_message(
			"Campaign %s should be %s but was %s" % [property, expected_value, actual_value]
		).is_equal(expected_value)

# Campaign phase testing
func assert_campaign_phase(campaign: Node, expected_phase: int) -> void:
	var current_phase := 0
	if campaign.has_method("get_current_phase"):
		current_phase = campaign.get_current_phase()
	assert_that(current_phase).override_failure_message(
		"Campaign should be in phase %d but was in phase %d" % [expected_phase, current_phase]
	).is_equal(expected_phase)

func await_campaign_phase(campaign: Node, expected_phase: int, timeout: float = CAMPAIGN_TEST_CONFIG.phase_timeout) -> bool:
	# Skip signal monitoring to prevent Dictionary corruption
	# monitor_signals(campaign)  # REMOVED - causes Dictionary corruption
	# Test state directly instead of signal emission
	var start_time := Time.get_ticks_msec()
	
	while campaign.has_method("get_current_phase") and campaign.get_current_phase() != expected_phase:
		if (Time.get_ticks_msec() - start_time) / 1000.0 > timeout:
			return false
		await get_tree().process_frame
	
	return true

# Campaign event testing
func simulate_campaign_event(campaign: Node, event_type: int, event_data: Dictionary = {}) -> void:
	if campaign.has_method("handle_event"):
		campaign.handle_event(event_type, event_data)
	await stabilize_engine()

func verify_campaign_event_handled(campaign: Node, event_type: int) -> void:
	var handled := false
	if campaign.has_method("was_event_handled"):
		handled = campaign.was_event_handled(event_type)
	assert_that(handled).override_failure_message(
		"Campaign should have handled event type %d" % event_type
	).is_true()

# Campaign save/load testing
func save_campaign_state(campaign: Node) -> Dictionary:
	if campaign.has_method("save_state"):
		return campaign.save_state()
	return {}

func load_campaign_state(campaign: Node, state: Dictionary) -> bool:
	if campaign.has_method("load_state"):
		return campaign.load_state(state)
	return false

func verify_campaign_persistence(campaign: Node) -> void:
	var original_state := save_campaign_state(campaign)
	var loaded_campaign := Node.new()
	track_node(loaded_campaign)
	
	assert_that(load_campaign_state(loaded_campaign, original_state)).override_failure_message(
		"Should be able to load saved campaign state"
	).is_true()
	
	var loaded_state := save_campaign_state(loaded_campaign)
	assert_that(loaded_state).override_failure_message(
		"Loaded campaign state should match original"
	).is_equal(original_state)

# Resource management
func create_test_resource(script: GDScript) -> Resource:
	var resource := Resource.new()
	if not resource:
		push_error("Failed to create test resource")
		return null
	track_resource(resource)
	return resource

func verify_resource_state(resource: Resource, expected_state: Dictionary) -> void:
	if not resource or not expected_state:
		push_error("Invalid resource or expected state")
		return
		
	for property in expected_state:
		var actual_value = resource.get(property)
		var expected_value = expected_state[property]
		assert_that(actual_value).override_failure_message(
			"Resource %s should be %s but was %s" % [property, expected_value, actual_value]
		).is_equal(expected_value)

# Campaign state assertions
func assert_campaign_resources(campaign: Node, expected_resources: Dictionary) -> void:
	for resource_type in expected_resources:
		var actual_amount := 0
		if campaign.has_method("get_resource_amount"):
			actual_amount = campaign.get_resource_amount(resource_type)
		var expected_amount: int = expected_resources[resource_type] as int
		assert_that(actual_amount).override_failure_message(
			"Campaign should have %d of resource %s but had %d" % [expected_amount, resource_type, actual_amount]
		).is_equal(expected_amount)

func assert_campaign_progress(campaign: Node, expected_progress: Dictionary) -> void:
	for progress_type in expected_progress:
		var actual_progress: float = 0.0
		if campaign.has_method("get_progress"):
			actual_progress = campaign.get_progress(progress_type) as float
		var expected_value: float = expected_progress[progress_type] as float
		assert_that(actual_progress).override_failure_message(
			"Campaign progress for %s should be %f but was %f" % [progress_type, expected_value, actual_progress]
		).is_equal(expected_value)

# Performance testing
func measure_campaign_performance(iterations: int = 100) -> Dictionary:
	var start_time = Time.get_time_dict_from_system()["unix"]
	
	for i in range(iterations):
		var campaign := create_test_campaign()
		if campaign:
			var campaign_node := Node.new()
			track_node(campaign_node)
			if campaign_node:
				simulate_campaign_event(campaign_node, 0) # TURN_START
				simulate_campaign_event(campaign_node, 1) # TURN_END
		await get_tree().process_frame
	
	var end_time = Time.get_time_dict_from_system()["unix"]
	var duration = end_time - start_time
	
	return {
		"duration_ms": duration * 1000.0,
		"iterations": iterations,
		"avg_per_iteration_ms": (duration * 1000.0) / iterations,
		"memory_usage": Performance.get_monitor(Performance.MEMORY_STATIC),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	}

# Helper methods
func wait_for_save() -> void:
	await get_tree().create_timer(CAMPAIGN_TEST_CONFIG.save_timeout).timeout

func wait_for_load() -> void:
	await get_tree().create_timer(CAMPAIGN_TEST_CONFIG.load_timeout).timeout