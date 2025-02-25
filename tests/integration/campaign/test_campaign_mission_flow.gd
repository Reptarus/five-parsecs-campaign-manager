@tool
extends "res://tests/fixtures/specialized/enemy_test_base.gd"

# Type-safe script references
const CampaignSystem := preload("res://src/core/campaign/CampaignSystem.gd")
const CampaignScript := preload("res://src/core/campaign/Campaign.gd")

# Type-safe instance variables
var _campaign_system: Node
var _received_signals: Array[String] = []

func before_all() -> void:
	await super.before_all()

func after_all() -> void:
	await super.after_all()

func before_each() -> void:
	await super.before_each()
	print("Setting up test environment...")
	
	# Initialize game state using framework method
	_game_state = create_test_game_state()
	if not _game_state:
		push_error("Failed to create test game state")
		return
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	# Load test campaign before validation
	load_test_campaign(_game_state)
	assert_valid_game_state(_game_state)
	
	# Set up campaign system
	_campaign_system = Node.new()
	_campaign_system.set_script(CampaignSystem)
	if not _campaign_system:
		push_error("Failed to create campaign system")
		return
	add_child_autofree(_campaign_system)
	track_test_node(_campaign_system)
	_connect_mission_signals()
	
	TypeSafeMixin._call_node_method_bool(_campaign_system, "initialize", [_game_state])
	await stabilize_engine(STABILIZE_TIME)
	
	print("Test environment setup complete")

func _connect_mission_signals() -> void:
	if not _campaign_system:
		push_error("Cannot connect signals: campaign system is null")
		return
		
	TypeSafeMixin._call_node_method_bool(_campaign_system, "connect", ["mission_created", _on_mission_created])
	TypeSafeMixin._call_node_method_bool(_campaign_system, "connect", ["mission_started", _on_mission_signal.bind("mission_started")])
	TypeSafeMixin._call_node_method_bool(_campaign_system, "connect", ["mission_setup_complete", _on_mission_signal.bind("mission_setup_complete")])
	TypeSafeMixin._call_node_method_bool(_campaign_system, "connect", ["mission_completed", _on_mission_completed])

# Signal handlers
func _on_mission_created(mission: Dictionary) -> void:
	_received_signals.append("mission_created")
	print("Mission created: %s" % mission.get("name", "Unknown"))

func _on_mission_signal(signal_name: String) -> void:
	_received_signals.append(signal_name)
	print("Mission signal received: %s" % signal_name)

func _on_mission_completed(success: bool) -> void:
	_received_signals.append("mission_completed")
	print("Mission completed with success: %s" % success)

func after_each() -> void:
	_disconnect_mission_signals()
	
	if is_instance_valid(_campaign_system):
		_campaign_system.queue_free()
	if is_instance_valid(_game_state):
		_game_state.queue_free()
		
	_campaign_system = null
	_game_state = null
	_received_signals.clear()
	
	await super.after_each()

func _disconnect_mission_signals() -> void:
	if not is_instance_valid(_campaign_system):
		return
	
	if _campaign_system.is_connected("mission_created", _on_mission_created):
		_campaign_system.disconnect("mission_created", _on_mission_created)
	if _campaign_system.is_connected("mission_started", _on_mission_signal):
		_campaign_system.disconnect("mission_started", _on_mission_signal)
	if _campaign_system.is_connected("mission_setup_complete", _on_mission_signal):
		_campaign_system.disconnect("mission_setup_complete", _on_mission_signal)
	if _campaign_system.is_connected("mission_completed", _on_mission_completed):
		_campaign_system.disconnect("mission_completed", _on_mission_completed)

# Helper Methods
func create_test_campaign() -> Resource:
	var campaign := Resource.new()
	campaign.set_script(CampaignScript)
	if not campaign:
		push_error("Failed to create campaign instance")
		return null
	
	# Initialize campaign with test data
	TypeSafeMixin._call_node_method_bool(campaign, "initialize", [])
	track_test_resource(campaign)
	return campaign

func assert_valid_game_state(state: Node) -> void:
	assert_not_null(state, "Game state should not be null")
	assert_true(state.has_method("get"), "Game state should have get method")
	
	# Verify required properties
	var campaign = TypeSafeMixin._call_node_method(state, "get", ["current_campaign"])
	assert_not_null(campaign, "Current campaign should be set")
	
	var difficulty = TypeSafeMixin._call_node_method_int(state, "get", ["difficulty_level"])
	assert_true(difficulty >= 0, "Difficulty level should be valid")
	
	# Verify boolean flags
	var permadeath = TypeSafeMixin._call_node_method_bool(state, "get", ["enable_permadeath"])
	var story_track = TypeSafeMixin._call_node_method_bool(state, "get", ["use_story_track"])
	var auto_save = TypeSafeMixin._call_node_method_bool(state, "get", ["auto_save_enabled"])
	
	assert_true(permadeath, "Permadeath should be enabled")
	assert_true(story_track, "Story track should be enabled")
	assert_true(auto_save, "Auto save should be enabled")

func load_test_campaign(state: Node) -> void:
	if not state:
		push_error("Cannot load campaign: game state is null")
		return
		
	var campaign := create_test_campaign()
	if not campaign:
		push_error("Failed to create test campaign")
		return
		
	TypeSafeMixin._call_node_method_bool(state, "set", ["current_campaign", campaign])
	TypeSafeMixin._call_node_method_bool(state, "set", ["difficulty_level", GameEnums.DifficultyLevel.NORMAL])
	TypeSafeMixin._call_node_method_bool(state, "set", ["enable_permadeath", true])
	TypeSafeMixin._call_node_method_bool(state, "set", ["use_story_track", true])
	TypeSafeMixin._call_node_method_bool(state, "set", ["auto_save_enabled", true])

# Utility method for waiting for a signal or timeout
func timeout_or_signal(source: Object, signal_name: String, timeout: float) -> void:
	var timer := get_tree().create_timer(timeout)
	
	var signal_wait = source.connect(signal_name, Callable(func(): pass ))
	await timer.timeout
	
	if source.is_connected(signal_name, Callable(func(): pass )):
		source.disconnect(signal_name, Callable(func(): pass ))

# Test Methods
func test_campaign_mission_flow() -> void:
	print("Testing campaign mission flow...")
	
	# Verify initial state
	assert_false(
		TypeSafeMixin._call_node_method_bool(_campaign_system, "is_mission_in_progress", []),
		"No mission should be in progress initially"
	)
	assert_null(
		TypeSafeMixin._call_node_method(_campaign_system, "get_current_mission", []),
		"No current mission should exist initially"
	)
	
	# Start mission
	TypeSafeMixin._call_node_method_bool(_campaign_system, "start_mission", [])
	
	# Wait for signals
	await stabilize_engine(0.5)
	
	# Verify signals were received in correct order
	var expected_signals = ["mission_created", "mission_started", "mission_setup_complete"]
	for i in range(expected_signals.size()):
		var expected = expected_signals[i]
		assert_true(i < _received_signals.size(), "Should have enough signals")
		assert_eq(_received_signals[i], expected,
			"Signal %d should be %s" % [i, expected])
	
	# Verify mission state
	var mission = TypeSafeMixin._call_node_method(_campaign_system, "get_current_mission", [])
	assert_not_null(mission, "Mission should be created")
	assert_eq(
		TypeSafeMixin._call_node_method_int(_campaign_system, "get_mission_phase", []),
		GameEnums.BattlePhase.SETUP,
		"Mission should be in setup phase"
	)
	
	# Verify mission is in progress
	assert_true(
		TypeSafeMixin._call_node_method_bool(_campaign_system, "is_mission_in_progress", []),
		"Mission should be in progress"
	)
	
	await get_tree().process_frame
	
	# End mission and verify cleanup
	TypeSafeMixin._call_node_method_bool(_campaign_system, "end_mission", [true])
	
	# Wait for cleanup
	await stabilize_engine(0.1)
	
	# Verify mission completed signal
	assert_true("mission_completed" in _received_signals,
		"Should have received mission_completed signal")
	
	# Verify cleanup
	assert_null(
		TypeSafeMixin._call_node_method(_campaign_system, "get_current_mission", []),
		"Mission should be cleaned up"
	)
	assert_false(
		TypeSafeMixin._call_node_method_bool(_campaign_system, "is_mission_in_progress", []),
		"Mission should not be in progress"
	)
	
	# Verify signal count
	assert_eq(_received_signals.size(), expected_signals.size() + 1,
		"Should have received exactly %d signals" % (expected_signals.size() + 1))
	
	print("Campaign mission flow test complete")

func test_campaign_initialization() -> void:
	# Create test campaign
	var campaign = CampaignScript.new()
	assert_true(
		TypeSafeMixin._call_node_method_bool(campaign, "initialize", [])
	)
	
	# Verify campaign state
	assert_true(campaign.has_method("get_name"), "Campaign should have name accessor")
	
	# Get state properties
	var state = _game_state
	var current_campaign = TypeSafeMixin._call_node_method(state, "get", ["current_campaign"])
	var difficulty = TypeSafeMixin._call_node_method_int(state, "get", ["difficulty_level"])
	
	# Verify preference settings
	var permadeath = TypeSafeMixin._call_node_method_bool(state, "get", ["enable_permadeath"])
	var story_track = TypeSafeMixin._call_node_method_bool(state, "get", ["use_story_track"])
	var auto_save = TypeSafeMixin._call_node_method_bool(state, "get", ["auto_save_enabled"])
	
	# We can set all these properties
	TypeSafeMixin._call_node_method_bool(state, "set", ["current_campaign", campaign])
	TypeSafeMixin._call_node_method_bool(state, "set", ["difficulty_level", GameEnums.DifficultyLevel.NORMAL])
	TypeSafeMixin._call_node_method_bool(state, "set", ["enable_permadeath", true])
	TypeSafeMixin._call_node_method_bool(state, "set", ["use_story_track", true])
	TypeSafeMixin._call_node_method_bool(state, "set", ["auto_save_enabled", true])

func test_mission_creation() -> void:
	# Verify no mission initially
	assert_false(
		TypeSafeMixin._call_node_method_bool(_campaign_system, "is_mission_in_progress", []),
		"No mission should be in progress initially"
	)
	
	assert_null(
		TypeSafeMixin._call_node_method(_campaign_system, "get_current_mission", []),
		"No mission should exist initially"
	)
	
	# Start a mission
	assert_true(
		TypeSafeMixin._call_node_method_bool(_campaign_system, "start_mission", [])
	)
	
	# Wait for mission creation
	await timeout_or_signal(_campaign_system, "mission_created", SIGNAL_TIMEOUT)
	
	# Verify signal was received
	assert_true(_received_signals.has("mission_created"), "Should receive mission_created signal")

func test_mission_flow() -> void:
	# Start a mission
	assert_true(TypeSafeMixin._call_node_method_bool(_campaign_system, "start_mission", []))
	
	# Wait for setup
	await timeout_or_signal(_campaign_system, "mission_setup_complete", SIGNAL_TIMEOUT)
	
	# Verify mission exists
	var mission = TypeSafeMixin._call_node_method(_campaign_system, "get_current_mission", [])
	assert_not_null(mission, "Mission should be created")
	
	assert_eq(
		TypeSafeMixin._call_node_method_int(_campaign_system, "get_mission_phase", []),
		GameEnums.BattlePhase.SETUP,
		"Mission should be in setup phase"
	)
	
	# Verify mission is in progress
	assert_true(
		TypeSafeMixin._call_node_method_bool(_campaign_system, "is_mission_in_progress", []),
		"Mission should be in progress"
	)
	
	# End the mission successfully
	assert_true(
		TypeSafeMixin._call_node_method_bool(_campaign_system, "end_mission", [true])
	)
	
	# Wait for completion
	await timeout_or_signal(_campaign_system, "mission_completed", SIGNAL_TIMEOUT)
	
	# Verify completion
	assert_true(_received_signals.has("mission_completed"), "Should receive mission_completed signal")
	
	assert_null(
		TypeSafeMixin._call_node_method(_campaign_system, "get_current_mission", []),
		"No mission should be active after completion"
	)
	
	assert_false(
		TypeSafeMixin._call_node_method_bool(_campaign_system, "is_mission_in_progress", []),
		"No mission should be in progress after completion"
	)
