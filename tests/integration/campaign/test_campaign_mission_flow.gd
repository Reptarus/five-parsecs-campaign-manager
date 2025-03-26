@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"

# Define missing constant
const SIGNAL_TIMEOUT: float = 2.0

# Type-safe script references
const CampaignSystem := preload("res://src/core/campaign/CampaignSystem.gd")
const CampaignScript := preload("res://src/core/campaign/Campaign.gd")

# Type-safe instance variables
var _mission_campaign_system: Node
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
	_mission_campaign_system = Node.new()
	_mission_campaign_system.set_script(CampaignSystem)
	if not _mission_campaign_system:
		push_error("Failed to create campaign system")
		return
	add_child_autofree(_mission_campaign_system)
	track_test_node(_mission_campaign_system)
	_connect_mission_signals()
	
	TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "initialize", [_game_state])
	await stabilize_engine(STABILIZE_TIME)
	
	print("Test environment setup complete")

func _connect_mission_signals() -> void:
	if not _mission_campaign_system:
		push_error("Cannot connect signals: campaign system is null")
		return
		
	TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "connect", ["mission_created", _on_mission_created])
	TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "connect", ["mission_started", _on_mission_signal.bind("mission_started")])
	TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "connect", ["mission_setup_complete", _on_mission_signal.bind("mission_setup_complete")])
	TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "connect", ["mission_completed", _on_mission_completed])

# Signal handlers
func _on_mission_created(mission: Variant) -> void:
	_received_signals.append("mission_created")
	if mission is Node:
		print("Mission created: %s" % mission.name)
	elif mission is Dictionary:
		print("Mission created: %s" % mission.get("name", "Unknown"))
	else:
		print("Mission created with unknown type: %s" % str(mission))

func _on_mission_signal(signal_name: String) -> void:
	_received_signals.append(signal_name)
	print("Mission signal received: %s" % signal_name)

func _on_mission_completed(success: bool) -> void:
	_received_signals.append("mission_completed")
	print("Mission completed with success: %s" % success)

func after_each() -> void:
	_disconnect_mission_signals()
	
	if is_instance_valid(_mission_campaign_system):
		_mission_campaign_system.queue_free()
	if is_instance_valid(_game_state):
		_game_state.queue_free()
		
	_mission_campaign_system = null
	_game_state = null
	_received_signals.clear()
	
	await super.after_each()

func _disconnect_mission_signals() -> void:
	if not is_instance_valid(_mission_campaign_system):
		return
	
	if _mission_campaign_system.is_connected("mission_created", _on_mission_created):
		_mission_campaign_system.disconnect("mission_created", _on_mission_created)
	if _mission_campaign_system.is_connected("mission_started", _on_mission_signal):
		_mission_campaign_system.disconnect("mission_started", _on_mission_signal)
	if _mission_campaign_system.is_connected("mission_setup_complete", _on_mission_signal):
		_mission_campaign_system.disconnect("mission_setup_complete", _on_mission_signal)
	if _mission_campaign_system.is_connected("mission_completed", _on_mission_completed):
		_mission_campaign_system.disconnect("mission_completed", _on_mission_completed)

# Helper Methods
func create_test_campaign() -> Resource:
	var campaign := Resource.new()
	track_test_resource(campaign)
	
	# Create a script with all necessary methods
	var script = GDScript.new()
	script.source_code = """extends Resource

# Campaign properties
var difficulty: int = 1
var name: String = "Test Campaign"
var id: String = "test_campaign"
var mission_count: int = 0
var completed_missions: Array = []

# Signals
signal campaign_state_changed(property)
signal resource_changed(resource_type, amount)
signal world_changed(world_data)

func initialize():
	difficulty = 1
	name = "Test Campaign"
	id = "test_campaign_" + str(Time.get_unix_time_from_system())
	return true

func get_difficulty():
	return difficulty
	
func set_difficulty(value: int):
	difficulty = value
	emit_signal("campaign_state_changed", "difficulty")
	
func add_enemy_experience(enemy, amount):
	if enemy and enemy.has_method("add_experience"):
		enemy.add_experience(amount)
	return true
	
func advance_difficulty():
	difficulty += 1
	emit_signal("campaign_state_changed", "difficulty")
	return true
"""
	script.reload()
	
	# Apply the script to the resource
	campaign.set_script(script)
	
	# Initialize the campaign
	TypeSafeMixin._call_node_method_bool(campaign, "initialize", [])
	
	return campaign

func assert_valid_game_state(state: Node) -> void:
	assert_not_null(state, "Game state should not be null")
	
	# Check for required methods
	assert_true(state.has_method("get_campaign_option") || state.has_method("get"),
		"Game state should have get or get_campaign_option method")
	
	# Verify required properties
	var campaign = null
	if state.has_method("get_current_campaign"):
		campaign = state.get_current_campaign()
	else:
		campaign = TypeSafeMixin._call_node_method(state, "get", ["current_campaign"])
	assert_not_null(campaign, "Current campaign should be set")
	
	# Verify difficulty level
	var difficulty = 0
	if state.has_method("get_difficulty_level"):
		difficulty = state.get_difficulty_level()
	else:
		difficulty = TypeSafeMixin._call_node_method_int(state, "get", ["difficulty_level"])
	assert_true(difficulty >= 0, "Difficulty level should be valid")
	
	# Verify boolean flags
	var permadeath = false
	var story_track = false
	var auto_save = false
	
	if state.has_method("get_campaign_option"):
		permadeath = TypeSafeMixin._call_node_method_bool(state, "get_campaign_option", ["permadeath_enabled", false])
		story_track = TypeSafeMixin._call_node_method_bool(state, "get_campaign_option", ["story_track_enabled", false])
		auto_save = TypeSafeMixin._call_node_method_bool(state, "get_campaign_option", ["auto_save_enabled", false])
	elif state.has_method("is_permadeath_enabled"):
		permadeath = state.is_permadeath_enabled()
		story_track = state.is_story_track_enabled()
		auto_save = state.is_auto_save_enabled()
	else:
		permadeath = TypeSafeMixin._call_node_method_bool(state, "get", ["enable_permadeath", false])
		story_track = TypeSafeMixin._call_node_method_bool(state, "get", ["use_story_track", false])
		auto_save = TypeSafeMixin._call_node_method_bool(state, "get", ["auto_save", false])
	
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
	
	# First try using direct methods if available
	if state.has_method("set_current_campaign"):
		state.set_current_campaign(campaign)
	else:
		TypeSafeMixin._call_node_method_bool(state, "set", ["current_campaign", campaign])
	
	# Set difficulty level
	if state.has_method("set_difficulty_level"):
		state.set_difficulty_level(GameEnums.DifficultyLevel.NORMAL)
	else:
		TypeSafeMixin._call_node_method_bool(state, "set", ["difficulty_level", GameEnums.DifficultyLevel.NORMAL])
	
	# Enable required settings using campaign options if available
	if state.has_method("set_campaign_option"):
		state.set_campaign_option("permadeath_enabled", true)
		state.set_campaign_option("story_track_enabled", true)
		state.set_campaign_option("auto_save_enabled", true)
	else:
		# Fallback to direct properties
		TypeSafeMixin._call_node_method_bool(state, "set", ["enable_permadeath", true])
		TypeSafeMixin._call_node_method_bool(state, "set", ["use_story_track", true])
		TypeSafeMixin._call_node_method_bool(state, "set", ["auto_save", true])

# Utility method for waiting for a signal or timeout
func timeout_or_signal(source: Object, signal_name: String, timeout: float) -> void:
	var timer := get_tree().create_timer(timeout)
	
	# Create a callback function that handles the signal
	var callback_obj = Node.new()
	add_child(callback_obj)
	callback_obj.set_script(GDScript.new())
	callback_obj.script.source_code = """extends Node

var signal_received = false

func on_signal_received(_arg1=null, _arg2=null, _arg3=null, _arg4=null):
	signal_received = true
"""
	callback_obj.script.reload()
	
	# Connect the signal to our callback function using Callable in Godot 4
	if source.has_signal(signal_name):
		source.connect(signal_name, Callable(callback_obj, "on_signal_received"))
	
	# Wait for the timeout
	await timer.timeout
	
	# Disconnect the signal if it was connected using Callable in Godot 4
	if source.has_signal(signal_name) and source.is_connected(signal_name, Callable(callback_obj, "on_signal_received")):
		source.disconnect(signal_name, Callable(callback_obj, "on_signal_received"))
	
	# Clean up
	callback_obj.queue_free()

# Test Methods
func test_campaign_mission_flow() -> void:
	print("Testing campaign mission flow...")
	
	# Verify initial state
	assert_false(
		TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "is_mission_in_progress", []),
		"No mission should be in progress initially"
	)
	assert_null(
		TypeSafeMixin._call_node_method(_mission_campaign_system, "get_current_mission", []),
		"No current mission should exist initially"
	)
	
	# Start mission
	TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "start_mission", [])
	
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
	var mission = TypeSafeMixin._call_node_method(_mission_campaign_system, "get_current_mission", [])
	assert_not_null(mission, "Mission should be created")
	assert_eq(
		TypeSafeMixin._call_node_method_int(_mission_campaign_system, "get_mission_phase", []),
		GameEnums.BattlePhase.SETUP,
		"Mission should be in setup phase"
	)
	
	# Verify mission is in progress
	assert_true(
		TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "is_mission_in_progress", []),
		"Mission should be in progress"
	)
	
	await get_tree().process_frame
	
	# End mission and verify cleanup
	TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "end_mission", [true])
	
	# Wait for cleanup
	await stabilize_engine(0.1)
	
	# Verify mission completed signal
	assert_true("mission_completed" in _received_signals,
		"Should have received mission_completed signal")
	
	# Verify cleanup
	assert_null(
		TypeSafeMixin._call_node_method(_mission_campaign_system, "get_current_mission", []),
		"Mission should be cleaned up"
	)
	assert_false(
		TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "is_mission_in_progress", []),
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
		TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "is_mission_in_progress", []),
		"No mission should be in progress initially"
	)
	
	assert_null(
		TypeSafeMixin._call_node_method(_mission_campaign_system, "get_current_mission", []),
		"No mission should exist initially"
	)
	
	# Start a mission
	assert_true(
		TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "start_mission", [])
	)
	
	# Wait for mission creation
	await timeout_or_signal(_mission_campaign_system, "mission_created", SIGNAL_TIMEOUT)
	
	# Verify signal was received
	assert_true(_received_signals.has("mission_created"), "Should receive mission_created signal")

func test_mission_flow() -> void:
	# Start a mission
	assert_true(TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "start_mission", []))
	
	# Wait for setup
	await timeout_or_signal(_mission_campaign_system, "mission_setup_complete", SIGNAL_TIMEOUT)
	
	# Verify mission exists
	var mission = TypeSafeMixin._call_node_method(_mission_campaign_system, "get_current_mission", [])
	assert_not_null(mission, "Mission should be created")
	
	assert_eq(
		TypeSafeMixin._call_node_method_int(_mission_campaign_system, "get_mission_phase", []),
		GameEnums.BattlePhase.SETUP,
		"Mission should be in setup phase"
	)
	
	# Verify mission is in progress
	assert_true(
		TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "is_mission_in_progress", []),
		"Mission should be in progress"
	)
	
	# End the mission successfully
	assert_true(
		TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "end_mission", [true])
	)
	
	# Wait for completion
	await timeout_or_signal(_mission_campaign_system, "mission_completed", SIGNAL_TIMEOUT)
	
	# Verify completion
	assert_true(_received_signals.has("mission_completed"), "Should receive mission_completed signal")
	
	assert_null(
		TypeSafeMixin._call_node_method(_mission_campaign_system, "get_current_mission", []),
		"No mission should be active after completion"
	)
	
	assert_false(
		TypeSafeMixin._call_node_method_bool(_mission_campaign_system, "is_mission_in_progress", []),
		"No mission should be in progress after completion"
	)

func test_permadeath_setting() -> void:
	# Enable permadeath setting
	if _game_state.has_method("set_campaign_option"):
		TypeSafeMixin._call_node_method_bool(_game_state, "set_campaign_option", ["permadeath_enabled", true])
	else:
		_game_state.set("permadeath_enabled", true)
		
	# Verify permadeath is enabled
	var permadeath_enabled = false
	if _game_state.has_method("get_campaign_option"):
		permadeath_enabled = TypeSafeMixin._call_node_method_bool(_game_state, "get_campaign_option", ["permadeath_enabled"])
	else:
		permadeath_enabled = _game_state.get("permadeath_enabled")
		
	assert_true(permadeath_enabled, "Permadeath should be enabled")

func test_story_track_setting() -> void:
	# Enable story track setting
	if _game_state.has_method("set_campaign_option"):
		TypeSafeMixin._call_node_method_bool(_game_state, "set_campaign_option", ["story_track_enabled", true])
	else:
		_game_state.set("story_track_enabled", true)
		
	# Verify story track is enabled
	var story_track_enabled = false
	if _game_state.has_method("get_campaign_option"):
		story_track_enabled = TypeSafeMixin._call_node_method_bool(_game_state, "get_campaign_option", ["story_track_enabled"])
	else:
		story_track_enabled = _game_state.get("story_track_enabled")
		
	assert_true(story_track_enabled, "Story track should be enabled")

func test_auto_save_setting() -> void:
	# Enable auto save setting
	if _game_state.has_method("set_campaign_option"):
		TypeSafeMixin._call_node_method_bool(_game_state, "set_campaign_option", ["auto_save_enabled", true])
	else:
		_game_state.set("auto_save_enabled", true)
		
	# Verify auto save is enabled
	var auto_save_enabled = false
	if _game_state.has_method("get_campaign_option"):
		auto_save_enabled = TypeSafeMixin._call_node_method_bool(_game_state, "get_campaign_option", ["auto_save_enabled"])
	else:
		auto_save_enabled = _game_state.get("auto_save_enabled")
		
	assert_true(auto_save_enabled, "Auto save should be enabled")
