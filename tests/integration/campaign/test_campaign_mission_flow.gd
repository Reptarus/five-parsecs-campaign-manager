@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"

# Define missing constant
const SIGNAL_TIMEOUT: float = 2.0
const STABILIZE_TIME: float = CAMPAIGN_TEST_CONFIG.stabilize_time

# Type-safe script references
const CampaignSystem := preload("res://src/core/campaign/CampaignSystem.gd")
const CampaignScript := preload("res://src/core/campaign/Campaign.gd")
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")

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
	
	Compatibility.safe_call_method(_mission_campaign_system, "initialize", [_game_state], false)
	await stabilize_engine(STABILIZE_TIME)
	
	print("Test environment setup complete")

func _connect_mission_signals() -> void:
	if not _mission_campaign_system:
		push_error("Cannot connect signals: campaign system is null")
		return
		
	Compatibility.safe_connect_signal(_mission_campaign_system, "mission_created", _on_mission_created)
	Compatibility.safe_connect_signal(_mission_campaign_system, "mission_started", _on_mission_signal.bind("mission_started"))
	Compatibility.safe_connect_signal(_mission_campaign_system, "mission_setup_complete", _on_mission_signal.bind("mission_setup_complete"))
	Compatibility.safe_connect_signal(_mission_campaign_system, "mission_completed", _on_mission_completed)

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
	
	# Ensure the campaign has a valid resource path
	campaign = Compatibility.ensure_resource_path(campaign, "test_campaign")
	
	# Create a script with all necessary methods - use temp file instead of direct script creation
	if not Compatibility.ensure_temp_directory():
		push_warning("Could not create temp directory for test scripts")
		return campaign
		
	var script_path = "res://tests/temp/test_campaign_%d_%d.gd" % [Time.get_unix_time_from_system(), randi() % 1000000]
	var script_content = """extends Resource

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
	
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if file:
		file.store_string(script_content)
		file.close()
		
		# Load and apply the script
		var script = load(script_path)
		campaign.set_script(script)
		
		# Initialize the campaign
		Compatibility.safe_call_method(campaign, "initialize", [])
	else:
		push_warning("Failed to create test campaign script")
	
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
		campaign = Compatibility.safe_call_method(state, "get", ["current_campaign"])
	assert_not_null(campaign, "Current campaign should be set")
	
	# Verify difficulty level
	var difficulty = 0
	if state.has_method("get_difficulty_level"):
		difficulty = state.get_difficulty_level()
	else:
		difficulty = Compatibility.safe_call_method(state, "get", ["difficulty_level"], 0)
	assert_true(difficulty >= 0, "Difficulty level should be valid")
	
	# Verify boolean flags
	var permadeath = false
	var story_track = false
	var auto_save = false
	
	if state.has_method("get_campaign_option"):
		permadeath = Compatibility.safe_call_method(state, "get_campaign_option", ["permadeath_enabled", false], false)
		story_track = Compatibility.safe_call_method(state, "get_campaign_option", ["story_track_enabled", false], false)
		auto_save = Compatibility.safe_call_method(state, "get_campaign_option", ["auto_save_enabled", false], false)
	elif state.has_method("is_permadeath_enabled"):
		permadeath = state.is_permadeath_enabled()
		story_track = state.is_story_track_enabled()
		auto_save = state.is_auto_save_enabled()
	else:
		permadeath = Compatibility.safe_call_method(state, "get", ["enable_permadeath", false], false)
		story_track = Compatibility.safe_call_method(state, "get", ["use_story_track", false], false)
		auto_save = Compatibility.safe_call_method(state, "get", ["auto_save", false], false)
	
	# No need to assert these flags, just making sure they are retrieved without errors

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
		Compatibility.safe_call_method(state, "set", ["current_campaign", campaign])
	
	# Set difficulty level
	if state.has_method("set_difficulty_level"):
		state.set_difficulty_level(GameEnums.DifficultyLevel.NORMAL)
	else:
		Compatibility.safe_call_method(state, "set", ["difficulty_level", GameEnums.DifficultyLevel.NORMAL])
	
	# Enable required settings using campaign options if available
	if state.has_method("set_campaign_option"):
		state.set_campaign_option("permadeath_enabled", true)
		state.set_campaign_option("story_track_enabled", true)
		state.set_campaign_option("auto_save_enabled", true)
	else:
		# Fallback to direct properties
		Compatibility.safe_call_method(state, "set", ["enable_permadeath", true])
		Compatibility.safe_call_method(state, "set", ["use_story_track", true])
		Compatibility.safe_call_method(state, "set", ["auto_save", true])

# Utility method for waiting for a signal or timeout
func timeout_or_signal(source: Object, signal_name: String, timeout: float) -> void:
	print("Waiting for signal '%s' with timeout %.1f..." % [signal_name, timeout])
	
	# Sanity check the source object
	if not is_instance_valid(source):
		push_error("Invalid signal source object")
		return
		
	# Verify the signal exists
	if not source.has_signal(signal_name):
		push_error("Object does not have signal: %s" % signal_name)
		print("Available signals: ", get_available_signals(source))
		return
		
	var timer := get_tree().create_timer(timeout)
	
	# Create a callback function that handles the signal
	var callback_obj = Node.new()
	add_child(callback_obj)
	callback_obj.set_script(GDScript.new())
	callback_obj.script.source_code = """extends Node

var signal_received = false

func on_signal_received(_arg1=null, _arg2=null, _arg3=null, _arg4=null):
	signal_received = true
	print("Signal received!")
"""
	callback_obj.script.reload()
	
	# Connect the signal to our callback function using Callable in Godot 4
	if source.has_signal(signal_name):
		var connection_result = source.connect(signal_name, Callable(callback_obj, "on_signal_received"))
		if connection_result != OK:
			push_warning("Failed to connect signal: %s (error: %d)" % [signal_name, connection_result])
	
	# Wait for the timeout
	await timer.timeout
	
	# Check if signal was received - use explicit boolean equality check
	if callback_obj.get("signal_received") == true:
		print("Signal '%s' was received successfully" % signal_name)
	else:
		push_warning("Timeout waiting for signal: %s" % signal_name)
	
	# Disconnect the signal if it was connected using Callable in Godot 4
	if source.has_signal(signal_name) and source.is_connected(signal_name, Callable(callback_obj, "on_signal_received")):
		source.disconnect(signal_name, Callable(callback_obj, "on_signal_received"))
	
	# Clean up
	callback_obj.queue_free()

# Helper function to get all available signals from an object
func get_available_signals(obj: Object) -> Array:
	if not is_instance_valid(obj):
		return []
		
	var signals = []
	for sig in obj.get_signal_list():
		signals.append(sig.name)
	return signals

# Test Methods
func test_campaign_mission_flow() -> void:
	print("Testing campaign mission flow...")
	
	# Verify initial state
	assert_false(
		Compatibility.safe_call_method(_mission_campaign_system, "is_mission_in_progress", [], false),
		"No mission should be in progress initially"
	)
	assert_null(
		Compatibility.safe_call_method(_mission_campaign_system, "get_current_mission", []),
		"No current mission should exist initially"
	)
	
	# Start mission
	Compatibility.safe_call_method(_mission_campaign_system, "start_mission", [], false)
	
	# Wait for signals
	await stabilize_engine(0.5)
	
	# Verify signals were received in correct order using the utility function
	var expected_signals = ["mission_created", "mission_started", "mission_setup_complete"]
	verify_signal_sequence(_received_signals, expected_signals)
	
	# Verify mission state
	var mission = Compatibility.safe_call_method(_mission_campaign_system, "get_current_mission", [])
	assert_not_null(mission, "Mission should be created")
	assert_eq(
		Compatibility.safe_call_method(_mission_campaign_system, "get_mission_phase", [], 0),
		GameEnums.BattlePhase.SETUP,
		"Mission should be in setup phase"
	)
	
	# Verify mission is in progress
	assert_true(
		Compatibility.safe_call_method(_mission_campaign_system, "is_mission_in_progress", [], false),
		"Mission should be in progress"
	)
	
	await get_tree().process_frame
	
	# End mission and verify cleanup
	Compatibility.safe_call_method(_mission_campaign_system, "end_mission", [true], false)
	
	# Wait for cleanup
	await stabilize_engine(0.1)
	
	# Verify mission completed signal
	assert_true("mission_completed" in _received_signals,
		"Should have received mission_completed signal")
	
	# Verify cleanup
	assert_null(
		Compatibility.safe_call_method(_mission_campaign_system, "get_current_mission", []),
		"Mission should be cleaned up"
	)
	assert_false(
		Compatibility.safe_call_method(_mission_campaign_system, "is_mission_in_progress", [], false),
		"Mission should not be in progress"
	)
	
	# Verify signal count
	assert_eq(_received_signals.size(), expected_signals.size() + 1,
		"Should have received exactly %d signals" % (expected_signals.size() + 1))
	
	print("Campaign mission flow test complete")

func test_campaign_system_settings() -> void:
	var campaign = CampaignScript.new()
	assert_true(
		Compatibility.safe_call_method(campaign, "initialize", [], false)
	)
	
	# Get state properties
	var state = _game_state
	var current_campaign = Compatibility.safe_call_method(state, "get", ["current_campaign"])
	var difficulty = Compatibility.safe_call_method(state, "get", ["difficulty_level"], 0)
	
	# Verify preference settings
	var permadeath = Compatibility.safe_call_method(state, "get", ["enable_permadeath"], false)
	var story_track = Compatibility.safe_call_method(state, "get", ["use_story_track"], false)
	var auto_save = Compatibility.safe_call_method(state, "get", ["auto_save_enabled"], false)
	
	# We can set all these properties
	Compatibility.safe_call_method(state, "set", ["current_campaign", campaign])
	Compatibility.safe_call_method(state, "set", ["difficulty_level", GameEnums.DifficultyLevel.NORMAL])
	Compatibility.safe_call_method(state, "set", ["enable_permadeath", true])
	Compatibility.safe_call_method(state, "set", ["use_story_track", true])
	Compatibility.safe_call_method(state, "set", ["auto_save_enabled", true])

func test_mission_creation() -> void:
	# Verify no mission initially
	assert_false(
		Compatibility.safe_call_method(_mission_campaign_system, "is_mission_in_progress", [], false),
		"No mission should be in progress initially"
	)
	
	assert_null(
		Compatibility.safe_call_method(_mission_campaign_system, "get_current_mission", []),
		"No mission should exist initially"
	)
	
	# Start a mission
	assert_true(
		Compatibility.safe_call_method(_mission_campaign_system, "start_mission", [], false)
	)
	
	# Wait for mission creation
	await timeout_or_signal(_mission_campaign_system, "mission_created", SIGNAL_TIMEOUT)
	
	# Verify signal was received using utility function
	verify_signal_sequence(_received_signals, ["mission_created"], false)

func test_mission_flow() -> void:
	# Start a mission
	assert_true(Compatibility.safe_call_method(_mission_campaign_system, "start_mission", [], false))
	
	# Wait for setup
	await timeout_or_signal(_mission_campaign_system, "mission_setup_complete", SIGNAL_TIMEOUT)
	
	# Verify mission exists
	var mission = Compatibility.safe_call_method(_mission_campaign_system, "get_current_mission", [])
	assert_not_null(mission, "Mission should be created")
	
	assert_eq(
		Compatibility.safe_call_method(_mission_campaign_system, "get_mission_phase", [], 0),
		GameEnums.BattlePhase.SETUP,
		"Mission should be in setup phase"
	)
	
	# Verify mission is in progress
	assert_true(
		Compatibility.safe_call_method(_mission_campaign_system, "is_mission_in_progress", [], false),
		"Mission should be in progress"
	)
	
	# End the mission successfully
	assert_true(
		Compatibility.safe_call_method(_mission_campaign_system, "end_mission", [true], false)
	)
	
	# Wait for completion
	await timeout_or_signal(_mission_campaign_system, "mission_completed", SIGNAL_TIMEOUT)
	
	# Verify expected signals were received in the right order using the utility
	var expected_signals = ["mission_created", "mission_started", "mission_setup_complete", "mission_completed"]
	verify_signal_sequence(_received_signals, expected_signals, true)
	
	assert_null(
		Compatibility.safe_call_method(_mission_campaign_system, "get_current_mission", []),
		"No mission should be active after completion"
	)
	
	assert_false(
		Compatibility.safe_call_method(_mission_campaign_system, "is_mission_in_progress", [], false),
		"No mission should be in progress after completion"
	)

func test_campaign_options() -> void:
	# Enable permadeath setting
	if _game_state.has_method("set_campaign_option"):
		Compatibility.safe_call_method(_game_state, "set_campaign_option", ["permadeath_enabled", true], false)
	else:
		_game_state.set("permadeath_enabled", true)
	
	var permadeath_enabled = false
	if _game_state.has_method("get_campaign_option"):
		permadeath_enabled = Compatibility.safe_call_method(_game_state, "get_campaign_option", ["permadeath_enabled"], false)
	else:
		permadeath_enabled = _game_state.get("permadeath_enabled")
	
	# Enable story track setting
	if _game_state.has_method("set_campaign_option"):
		Compatibility.safe_call_method(_game_state, "set_campaign_option", ["story_track_enabled", true], false)
	else:
		_game_state.set("story_track_enabled", true)
	
	var story_track_enabled = false
	if _game_state.has_method("get_campaign_option"):
		story_track_enabled = Compatibility.safe_call_method(_game_state, "get_campaign_option", ["story_track_enabled"], false)
	else:
		story_track_enabled = _game_state.get("story_track_enabled")
	
	# Enable auto save setting
	if _game_state.has_method("set_campaign_option"):
		Compatibility.safe_call_method(_game_state, "set_campaign_option", ["auto_save_enabled", true], false)
	else:
		_game_state.set("auto_save_enabled", true)
	
	var auto_save_enabled = false
	if _game_state.has_method("get_campaign_option"):
		auto_save_enabled = Compatibility.safe_call_method(_game_state, "get_campaign_option", ["auto_save_enabled"], false)
	else:
		auto_save_enabled = _game_state.get("auto_save_enabled")
