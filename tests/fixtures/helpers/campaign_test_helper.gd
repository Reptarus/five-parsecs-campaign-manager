@tool
extends GameTest

# Type-safe error handling
const ERROR_CAMPAIGN_NULL := "Campaign is null"
const ERROR_CAMPAIGN_NOT_INIT := "Campaign not initialized"
const ERROR_INVALID_STATE_KEY := "Invalid campaign state key: %s"
const ERROR_MANAGER_NULL := "Failed to create %s"
const ERROR_SIGNAL_MISSING := "Missing required signal: %s"
const ERROR_PHASE_MISMATCH := "Campaign should be in phase %d but was in phase %d"
const ERROR_RESOURCE_MISMATCH := "Campaign %s should be %d but was %d"
const ERROR_STORY_EVENT_FAILED := "Story event '%s' failed to trigger"
const ERROR_PERFORMANCE_NO_DATA := "No performance data available for %s"

# Type-safe constants for campaign testing
const DEFAULT_TIMEOUT := 1.0 as float
const CAMPAIGN_SETUP_TIMEOUT := 2.0 as float
const CAMPAIGN_STABILIZE_TIME := 0.1 as float
const PERFORMANCE_ITERATIONS := 100 as int

# Type-safe enums
enum CampaignPhase {
	SETUP,
	STORY,
	BATTLE,
	RESOLUTION
}

# Type-safe test campaign states
const TEST_CAMPAIGN_STATES := {
	"SETUP": {
		"phase": GameEnums.FiveParcsecsCampaignPhase.SETUP as int,
		"resources": {
			"credits": 100 as int,
			"reputation": 0 as int
		}
	},
	"STORY": {
		"phase": GameEnums.FiveParcsecsCampaignPhase.STORY as int,
		"resources": {
			"credits": 150 as int,
			"reputation": 5 as int
		}
	},
	"BATTLE": {
		"phase": GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP as int,
		"resources": {
			"credits": 200 as int,
			"reputation": 10 as int
		}
	}
}

# Type-safe instance variables
var _campaign: Resource = null
var _campaign_manager: Node = null
var _story_manager: Node = null

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize test components
	_campaign = create_test_campaign()
	if not _campaign:
		push_error("Failed to create test campaign")
		return
	track_test_resource(_campaign)
	
	_campaign_manager = _create_test_manager("CampaignManager")
	if not _campaign_manager:
		return
	
	_story_manager = _create_test_manager("StoryManager")
	if not _story_manager:
		return
	
	await stabilize_engine()

func after_each() -> void:
	_campaign = null
	_campaign_manager = null
	_story_manager = null
	await super.after_each()

# Campaign Phase Testing Methods
func verify_campaign_phase_transition(campaign: Resource, from_phase: int, to_phase: int) -> void:
	if not is_instance_valid(campaign):
		push_error(ERROR_CAMPAIGN_NULL)
		return
		
	var current_phase := _call_resource_method_int(campaign, "get_phase")
	assert_eq(current_phase, from_phase,
		ERROR_PHASE_MISMATCH % [from_phase, current_phase])
	
	# Watch for phase change signals
	watch_signals(campaign)
	
	# Attempt phase transition
	_call_resource_method(campaign, "transition_to_phase", [to_phase])
	
	# Verify the phase changed
	current_phase = _call_resource_method_int(campaign, "get_phase")
	assert_eq(current_phase, to_phase,
		ERROR_PHASE_MISMATCH % [to_phase, current_phase])
	verify_signal_emitted(campaign, "phase_changed")

func verify_invalid_phase_transition(campaign: Resource, from_phase: int, to_phase: int) -> void:
	if not is_instance_valid(campaign):
		push_error(ERROR_CAMPAIGN_NULL)
		return
		
	var current_phase := _call_resource_method_int(campaign, "get_phase")
	assert_eq(current_phase, from_phase,
		ERROR_PHASE_MISMATCH % [from_phase, current_phase])
	
	# Watch for phase change signals
	watch_signals(campaign)
	
	# Attempt invalid phase transition
	_call_resource_method(campaign, "transition_to_phase", [to_phase])
	
	# Verify phase did not change
	current_phase = _call_resource_method_int(campaign, "get_phase")
	assert_eq(current_phase, from_phase,
		ERROR_PHASE_MISMATCH % [from_phase, current_phase])
	verify_signal_not_emitted(campaign, "phase_changed")

# Resource Management Methods
func verify_campaign_resources(campaign: Resource, expected_resources: Dictionary) -> void:
	if not is_instance_valid(campaign):
		push_error(ERROR_CAMPAIGN_NULL)
		return
		
	for resource_name in expected_resources:
		var actual_value := _call_resource_method_int(campaign, "get_%s" % resource_name, [])
		var expected_value: int = expected_resources[resource_name]
		assert_eq(actual_value, expected_value,
			ERROR_RESOURCE_MISMATCH % [resource_name, expected_value, actual_value])

# Signal Testing Methods
func verify_missing_signals(emitter: Object, expected_signals: Array[String]) -> void:
	if not is_instance_valid(emitter):
		push_error(ERROR_CAMPAIGN_NULL)
		return
		
	for signal_name in expected_signals:
		if not emitter.has_signal(signal_name):
			assert_false(true, ERROR_SIGNAL_MISSING % signal_name)
		else:
			verify_signal_not_emitted(emitter, signal_name)

# Story Testing Methods
func verify_story_progression(campaign: Resource, story_event: String) -> void:
	if not campaign:
		push_error("Campaign is null")
		return
		
	watch_signals(campaign)
	var success: bool = _call_resource_method_bool(campaign, "trigger_story_event", [story_event])
	assert_true(success, "Story event should trigger successfully")
	verify_signal_emitted(campaign, "story_event_completed")

# Campaign State Verification
func verify_campaign_state(campaign: Resource, expected_state: Dictionary) -> void:
	if not campaign:
		push_error("Campaign is null")
		return
		
	# Verify phase
	var phase: int = expected_state.get("phase", GameEnums.FiveParcsecsCampaignPhase.SETUP)
	assert_eq(_call_resource_method_int(campaign, "get_phase"), phase,
		"Campaign should be in correct phase")
	
	# Verify resources
	var resources: Dictionary = expected_state.get("resources", {})
	verify_campaign_resources(campaign, resources)

# Helper Methods for State Management
func verify_campaign_state_by_key(campaign: Resource, state_key: String) -> void:
	if not campaign:
		push_error("Campaign is null")
		return
		
	if not state_key in TEST_CAMPAIGN_STATES:
		push_error("Invalid campaign state key: %s" % state_key)
		return
		
	verify_campaign_state(campaign, TEST_CAMPAIGN_STATES[state_key])

# Helper Methods
func create_test_campaign() -> Resource:
	var campaign: Resource = load("res://src/core/campaign/Campaign.gd").new()
	if not campaign:
		push_error("Failed to create campaign instance")
		return null
		
	track_test_resource(campaign)
	return campaign

func setup_test_campaign_state(state_key: String) -> void:
	if not _campaign:
		push_error("Campaign not initialized")
		return
		
	if not state_key in TEST_CAMPAIGN_STATES:
		push_error("Invalid campaign state key: %s" % state_key)
		return
		
	var state: Dictionary = TEST_CAMPAIGN_STATES[state_key]
	_call_resource_method(_campaign, "set_phase", [state.phase])
	
	for resource_name in state.resources:
		var value: int = state.resources[resource_name]
		_call_resource_method(_campaign, "set_%s" % resource_name, [value])

# Performance Testing Methods
func measure_campaign_performance(test_function: Callable, iterations: int = 100) -> Dictionary:
	var results := {
		"phase_transitions": [],
		"story_events": [],
		"resource_updates": []
	}
	
	for i in range(iterations):
		var start_time := Time.get_ticks_msec()
		await test_function.call()
		var duration := Time.get_ticks_msec() - start_time
		
		match i % 3:
			0: results.phase_transitions.append(duration)
			1: results.story_events.append(duration)
			2: results.resource_updates.append(duration)
	
	return {
		"average_phase_transition_ms": _calculate_average(results.phase_transitions),
		"average_story_event_ms": _calculate_average(results.story_events),
		"average_resource_update_ms": _calculate_average(results.resource_updates)
	}

# Statistical Helper Methods
func _calculate_average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum: float = 0.0
	for value in values:
		sum += value
	return sum / values.size()

func _create_test_manager(manager_name: String) -> Node:
	var manager := Node.new()
	if not manager:
		push_error(ERROR_MANAGER_NULL % manager_name)
		return null
		
	manager.name = manager_name
	add_child_autofree(manager)
	track_test_node(manager)
	return manager
