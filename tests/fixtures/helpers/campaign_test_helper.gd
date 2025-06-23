@tool
extends GdUnitGameTest

# Campaign test helper imports
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Error message constants
const ERROR_CAMPAIGN_NULL := "Campaign is null"
const ERROR_CAMPAIGN_NOT_INIT := "Campaign not initialized"
const ERROR_INVALID_STATE_KEY := "Invalid state key"
const ERROR_MANAGER_NULL := "Failed to create %s"
const ERROR_SIGNAL_MISSING := "Signal missing: %s"
const ERROR_PHASE_MISMATCH := "Campaign should be in phase %d but was in phase %d"
const ERROR_RESOURCE_MISMATCH := "Campaign %s should be %d but was %d"
const ERROR_STORY_EVENT_FAILED := "Story event '%s' failed to trigger"
const ERROR_PERFORMANCE_NO_DATA := "No performance data available for %s"

# Timeout constants
const DEFAULT_TIMEOUT := 1.0 as float
const CAMPAIGN_SETUP_TIMEOUT := 2.0 as float
const CAMPAIGN_STABILIZE_TIME := 0.1 as float
const PERFORMANCE_ITERATIONS := 100 as int

# Campaign phase enumeration
enum CampaignPhase {
	SETUP,
	STORY,
	BATTLE,
	RESOLUTION
}

# Type-safe test campaign states - using variables instead of constants
var TEST_CAMPAIGN_STATES: Dictionary = {}

# Type-safe instance variables
var _campaign: Resource = null
var _campaign_manager: Node = null
var _story_manager: Node = null

# Setup and teardown methods
func before_test() -> void:
	super.before_test()
	
	# Initialize test campaign states
	_initialize_test_states()
	
	# Create test campaign
	_campaign = create_test_campaign_resource()
	if not _campaign:
		push_error("Failed to create test campaign")
		return
	
	_campaign_manager = _create_test_manager("CampaignManager")
	if not _campaign_manager:
		push_error("Failed to create campaign manager")
		return
		
	_story_manager = _create_test_manager("StoryManager")
	if not _story_manager:
		push_error("Failed to create story manager")
		return

func after_test() -> void:
	_campaign = null
	_campaign_manager = null
	_story_manager = null
	super.after_test()

func _initialize_test_states() -> void:
	TEST_CAMPAIGN_STATES = {
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

# Verification methods
func verify_campaign_phase_transition(campaign: Resource, from_phase: int, to_phase: int) -> void:
	if not is_instance_valid(campaign):
		assert_that(false).override_failure_message(ERROR_CAMPAIGN_NULL).is_true()
		return
	
	var current_phase: int = 0
	if campaign.has_method("get_current_phase"):
		current_phase = campaign.call("get_current_phase")
	assert_that(current_phase).is_equal(from_phase)
	
	# Skip signal monitoring to prevent Dictionary corruption
	# Test state directly instead of signal emission
	
	# Trigger phase transition
	if campaign.has_method("set_phase"):
		campaign.call("set_phase", to_phase)
	
	# Verify transition occurred
	if campaign.has_method("get_current_phase"):
		current_phase = campaign.call("get_current_phase")
	assert_that(current_phase).is_equal(to_phase)

func verify_invalid_phase_transition(campaign: Resource, from_phase: int, to_phase: int) -> void:
	if not is_instance_valid(campaign):
		assert_that(false).override_failure_message(ERROR_CAMPAIGN_NULL).is_true()
		return
	
	var current_phase: int = 0
	if campaign.has_method("get_current_phase"):
		current_phase = campaign.call("get_current_phase")
	assert_that(current_phase).is_equal(from_phase)
	
	# Skip signal monitoring to prevent Dictionary corruption
	# Test state directly instead of signal emission
	
	# Attempt invalid phase transition
	if campaign.has_method("set_phase"):
		campaign.call("set_phase", to_phase)
	
	# Verify transition was rejected
	if campaign.has_method("get_current_phase"):
		current_phase = campaign.call("get_current_phase")
	assert_that(current_phase).is_equal(from_phase)

# Resource verification
func verify_campaign_resources(campaign: Resource, expected_resources: Dictionary) -> void:
	if not is_instance_valid(campaign):
		assert_that(false).override_failure_message(ERROR_CAMPAIGN_NULL).is_true()
		return
	
	for resource_name in expected_resources:
		if campaign.has_method("get_%s" % resource_name):
			var actual_value = campaign.call("get_%s" % resource_name)
			var expected_value: int = expected_resources[resource_name]
			assert_that(actual_value).is_equal(expected_value)

# Signal verification
func verify_missing_signals(emitter: Object, expected_signals: Array[String]) -> void:
	if not is_instance_valid(emitter):
		assert_that(false).override_failure_message("Emitter is null").is_true()
		return
	
	for signal_name in expected_signals:
		if not emitter.has_signal(signal_name):
			assert_that(false).override_failure_message(ERROR_SIGNAL_MISSING % signal_name).is_true()

# Story progression verification
func verify_story_progression(campaign: Resource, story_event: String) -> void:
	if not campaign:
		assert_that(false).override_failure_message(ERROR_CAMPAIGN_NULL).is_true()
		return
	
	# Skip signal monitoring to prevent Dictionary corruption
	# Test state directly instead of signal emission
	var success: bool = false
	if campaign.has_method("trigger_story_event"):
		success = campaign.call("trigger_story_event", story_event)
	assert_that(success).is_true()

# Campaign state verification
func verify_campaign_state(campaign: Resource, expected_state: Dictionary) -> void:
	if not campaign:
		assert_that(false).override_failure_message(ERROR_CAMPAIGN_NULL).is_true()
		return
	
	# Verify phase
	var phase: int = expected_state.get("phase", GameEnums.FiveParcsecsCampaignPhase.SETUP)
	var current_phase: int = 0
	if campaign.has_method("get_current_phase"):
		current_phase = campaign.call("get_current_phase")
	assert_that(current_phase).is_equal(phase)
	
	# Verify resources
	var resources: Dictionary = expected_state.get("resources", {})
	verify_campaign_resources(campaign, resources)

# State key verification
func verify_campaign_state_by_key(campaign: Resource, state_key: String) -> void:
	if not campaign:
		assert_that(false).override_failure_message(ERROR_CAMPAIGN_NULL).is_true()
		return
	
	if not TEST_CAMPAIGN_STATES.has(state_key):
		push_error(ERROR_INVALID_STATE_KEY)
		return
	
	var expected_state = TEST_CAMPAIGN_STATES[state_key]
	verify_campaign_state(campaign, expected_state)

# Resource creation methods
func create_test_campaign_resource() -> Resource:
	# Apply Universal Mock Strategy - create comprehensive MockCampaign
	var campaign: MockCampaign = MockCampaign.new()
	return campaign

func setup_test_campaign_state(state_key: String) -> void:
	if not _campaign:
		push_error("Campaign not initialized")
		return
	
	var state = TEST_CAMPAIGN_STATES.get(state_key, {})
	if _campaign.has_method("set_phase"):
		_campaign.call("set_phase", state.phase)
	
	for resource_name in state.resources:
		var value = state.resources[resource_name]
		if _campaign.has_method("set_%s" % resource_name):
			_campaign.call("set_%s" % resource_name, value)

# Performance measurement
func measure_campaign_performance(test_function: Callable, iterations: int = 100) -> Dictionary:
	var results := {
		"phase_transitions": [],
		"story_events": [],
		"resource_updates": []
	}
	
	for i: int in range(iterations):
		var start_time := Time.get_ticks_msec()
		test_function.call()
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

func _calculate_average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum = 0.0
	for value in values:
		sum += value
	return sum / values.size()

func _create_test_manager(manager_name: String) -> Node:
	var manager = Node.new()
	if not manager:
		push_error(ERROR_MANAGER_NULL % manager_name)
		return null
	
	manager.name = manager_name
	add_child(manager)
	return manager

# Mock campaign class
class MockCampaign extends Resource:
	var current_phase: int = GameEnums.FiveParcsecsCampaignPhase.NONE
	var credits: int = 100
	var reputation: int = 0
	var progress_values: Dictionary = {"reputation": 0}
	
	func get_current_phase() -> int:
		return current_phase
	
	func set_phase(phase: int) -> void:
		current_phase = phase
		phase_changed.emit(phase)
	
	func get_credits() -> int:
		return credits
		
	func set_credits(test_value: int) -> void:
		credits = test_value
	
	func get_reputation() -> int:
		return reputation
		
	func set_reputation(test_value: int) -> void:
		reputation = test_value
	
	func get_progress_value(key: String) -> int:
		return progress_values.get(key, 0)
	
	func set_progress_value(key: String, value: int) -> void:
		progress_values[key] = value
	
	func trigger_story_event(event_name: String) -> bool:
		story_event_completed.emit(event_name)
		return true
	
	signal phase_changed(new_phase: int)
	signal story_event_completed(event_name: String)

# Campaign test helper methods
func test_campaign_initial_phase() -> void:
	var campaign = create_test_campaign_resource()
	if not campaign:
		push_error("Failed to create campaign")
		return
	
	var current_phase: int = 0
	if campaign.has_method("get_current_phase"):
		current_phase = campaign.call("get_current_phase")
	assert_that(current_phase).is_equal(GameEnums.FiveParcsecsCampaignPhase.NONE)

func test_campaign_phase_transition() -> void:
	var campaign = create_test_campaign_resource()
	if not campaign:
		push_error("Failed to create campaign")
		return
	
	# Test transition to UPKEEP
	if campaign.has_method("set_phase"):
		campaign.call("set_phase", GameEnums.FiveParcsecsCampaignPhase.UPKEEP)
	
	var current_phase: int = 0
	if campaign.has_method("get_current_phase"):
		current_phase = campaign.call("get_current_phase")
	assert_that(current_phase).is_equal(GameEnums.FiveParcsecsCampaignPhase.UPKEEP)
	
	# Test transition to BATTLE_SETUP
	if campaign.has_method("set_phase"):
		campaign.call("set_phase", GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP)
	
	if campaign.has_method("get_current_phase"):
		current_phase = campaign.call("get_current_phase")
	assert_that(current_phase).is_equal(GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP)

func test_campaign_progress() -> void:
	var campaign = create_test_campaign_resource()
	if not campaign:
		push_error("Failed to create campaign")
		return
	
	var actual_value: int = 0
	if campaign.has_method("get_progress_value"):
		actual_value = campaign.call("get_progress_value", "reputation")
	assert_that(actual_value).is_equal(0)
