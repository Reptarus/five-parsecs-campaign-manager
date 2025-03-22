@tool
extends "res://tests/fixtures/base/game_test.gd"

# Do not redefine GameEnums or TestEnums - use the parent class's implementation
# const GameEnums = TestEnums.GlobalEnums

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
	"difficulty": GameEnums.DifficultyLevel.NORMAL as int,
	"permadeath": true as bool,
	"story_track": true as bool,
	"auto_save": true as bool
}

# Setup methods
func before_each() -> void:
	await super.before_each()
	if not await setup_campaign_systems():
		push_error("Failed to setup campaign systems")
		return
	await stabilize_engine()

func after_each() -> void:
	_cleanup_campaign_resources()
	await super.after_each()

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
	add_child_autofree(_campaign_system)
	track_test_node(_campaign_system)
	return true

# Resource cleanup
func _cleanup_campaign_resources() -> void:
	_campaign_system = null
	_campaign_data = null

# Required interface implementations
func create_test_campaign() -> Resource:
	var campaign := Resource.new()
	if not campaign:
		push_error("Failed to create campaign resource")
		return null
	track_test_resource(campaign)
	return campaign

func verify_campaign_state(campaign: Resource, expected_state: Dictionary) -> void:
	if not campaign or not expected_state:
		push_error("Invalid campaign or expected state")
		return
		
	for property in expected_state:
		var actual_value = _call_node_method(campaign, "get_" + property)
		var expected_value = expected_state[property]
		assert_eq(actual_value, expected_value,
			"Campaign %s should be %s but was %s" % [property, expected_value, actual_value])

# Campaign phase testing
func assert_campaign_phase(campaign: Node, expected_phase: int) -> void:
	var current_phase := _call_node_method_int(campaign, "get_current_phase", [], -1)
	assert_eq(current_phase, expected_phase,
		"Campaign should be in phase %d but was in phase %d" % [expected_phase, current_phase])

func await_campaign_phase(campaign: Node, expected_phase: int, timeout: float = CAMPAIGN_TEST_CONFIG.phase_timeout) -> bool:
	watch_signals(campaign)
	var start_time := Time.get_ticks_msec()
	
	while _call_node_method_int(campaign, "get_current_phase", [], -1) != expected_phase:
		if (Time.get_ticks_msec() - start_time) / 1000.0 > timeout:
			return false
		await get_tree().process_frame
	
	return true

# Campaign event testing
func simulate_campaign_event(campaign: Node, event_type: int, event_data: Dictionary = {}) -> void:
	_call_node_method_bool(campaign, "handle_event", [event_type, event_data])
	await stabilize_engine()

func verify_campaign_event_handled(campaign: Node, event_type: int) -> void:
	var handled := _call_node_method_bool(campaign, "was_event_handled", [event_type])
	assert_true(handled, "Campaign should have handled event type %d" % event_type)

# Campaign save/load testing
func save_campaign_state(campaign: Node) -> Dictionary:
	return _call_node_method_dict(campaign, "save_state", [])

func load_campaign_state(campaign: Node, state: Dictionary) -> bool:
	return _call_node_method_bool(campaign, "load_state", [state])

func verify_campaign_persistence(campaign: Node) -> void:
	var original_state := save_campaign_state(campaign)
	var loaded_campaign := create_test_node(campaign.get_script())
	
	assert_true(load_campaign_state(loaded_campaign, original_state),
		"Should be able to load saved campaign state")
	
	var loaded_state := save_campaign_state(loaded_campaign)
	assert_eq(original_state, loaded_state,
		"Loaded campaign state should match original")

# Resource management
func create_test_resource(script: GDScript) -> Resource:
	var resource := Resource.new()
	if not resource:
		push_error("Failed to create test resource")
		return null
	track_test_resource(resource)
	return resource

func verify_resource_state(resource: Resource, expected_state: Dictionary) -> void:
	if not resource or not expected_state:
		push_error("Invalid resource or expected state")
		return
		
	for property in expected_state:
		var actual_value = resource.get(property)
		var expected_value = expected_state[property]
		assert_eq(actual_value, expected_value,
			"Resource %s should be %s but was %s" % [property, expected_value, actual_value])

# Campaign state assertions
func assert_campaign_resources(campaign: Node, expected_resources: Dictionary) -> void:
	for resource_type in expected_resources:
		var actual_amount := _call_node_method_int(campaign, "get_resource_amount", [resource_type])
		var expected_amount: int = expected_resources[resource_type] as int
		assert_eq(actual_amount, expected_amount,
			"Campaign should have %d of resource %s but had %d" % [expected_amount, resource_type, actual_amount])

func assert_campaign_progress(campaign: Node, expected_progress: Dictionary) -> void:
	for progress_type in expected_progress:
		var actual_progress: float = _call_node_method_int(campaign, "get_progress", [progress_type]) as float
		var expected_value: float = expected_progress[progress_type] as float
		assert_eq(actual_progress, expected_value,
			"Campaign progress for %s should be %f but was %f" % [progress_type, expected_value, actual_progress])

# Performance testing
func measure_campaign_performance(iterations: int = 100) -> Dictionary:
	# Clear performance samples
	fps_samples.clear()
	Performance.get_monitor(Performance.TIME_FPS)
	Performance.get_monitor(Performance.MEMORY_STATIC)
	Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	for i in range(iterations):
		var campaign := create_test_campaign()
		if campaign:
			var campaign_node := create_test_node(campaign.get_script())
			if campaign_node:
				simulate_campaign_event(campaign_node, GlobalEnums.CampaignEvent.TURN_START)
				simulate_campaign_event(campaign_node, GlobalEnums.CampaignEvent.TURN_END)
		await get_tree().process_frame
	
	# Calculate results
	var avg_fps := 0.0
	if not fps_samples.is_empty():
		for fps in fps_samples:
			avg_fps += fps
		avg_fps /= fps_samples.size()
	
	return {
		"average_fps": avg_fps,
		"memory_usage": Performance.get_monitor(Performance.MEMORY_STATIC),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	}

# Helper methods
func wait_for_save() -> void:
	await get_tree().create_timer(CAMPAIGN_TEST_CONFIG.save_timeout).timeout

func wait_for_load() -> void:
	await get_tree().create_timer(CAMPAIGN_TEST_CONFIG.load_timeout).timeout

# Add missing assertion functions to ensure availability
func assert_le(a, b, text: String = "") -> void:
	if text.length() > 0:
		assert_true(a <= b, text)
	else:
		assert_true(a <= b, "Expected %s <= %s" % [a, b])

func assert_ge(a, b, text: String = "") -> void:
	if text.length() > 0:
		assert_true(a >= b, text)
	else:
		assert_true(a >= b, "Expected %s >= %s" % [a, b])

# Add this helper method to fix the missing function error
func get_current_test_object():
	if _gut and _gut.has_method("get_current_test_object"):
		return _gut.get_current_test_object()
	return null