@tool
extends "res://tests/fixtures/game_test.gd"
class_name TestCampaignMissionFlow

const FiveParsecsCampaignSystem := preload("res://src/core/campaign/CampaignSystem.gd")

var campaign_system: FiveParsecsCampaignSystem
var game_state: Node

# Signal tracking
var _received_signals: Array = []

func _do_ready_stuff() -> void:
	super._do_ready_stuff()

func before_all() -> void:
	await super.before_all()

func after_all() -> void:
	await super.after_all()

func before_each() -> void:
	await super.before_each()
	gut.p("Setting up test environment...")
	
	# Initialize game state using framework method
	game_state = create_test_game_state()
	add_child_autofree(game_state)
	track_test_node(game_state)
	
	# Load test campaign before validation
	load_test_campaign(game_state)
	assert_valid_game_state(game_state)
	get_tree().process_frame
	
	# Set up campaign system
	campaign_system = FiveParsecsCampaignSystem.new()
	add_child_autofree(campaign_system)
	track_test_node(campaign_system)
	_connect_mission_signals()
	campaign_system.initialize(game_state)
	get_tree().process_frame
	
	gut.p("Test environment setup complete")

func _connect_mission_signals() -> void:
	campaign_system.mission_created.connect(_on_mission_created)
	campaign_system.mission_started.connect(_on_mission_signal.bind("mission_started"))
	campaign_system.mission_setup_complete.connect(_on_mission_signal.bind("mission_setup_complete"))
	campaign_system.mission_completed.connect(_on_mission_completed)

func _on_mission_created(mission: Node) -> void:
	_received_signals.append("mission_created")
	track_test_node(mission) # Track the created mission node
	gut.p("Mission created: " + str(mission))

func _on_mission_signal(signal_name: String) -> void:
	_received_signals.append(signal_name)
	gut.p("Received signal: " + signal_name)

func _on_mission_completed(success: bool) -> void:
	_received_signals.append("mission_completed")
	gut.p("Mission completed with success: %s" % success)

func after_each() -> void:
	if campaign_system and campaign_system.is_mission_in_progress():
		campaign_system.end_mission()
	
	_received_signals.clear()
	if is_instance_valid(campaign_system):
		_disconnect_mission_signals()
	
	# Let parent handle cleanup of tracked nodes and resources
	await super.after_each()
	
	# Clear references to allow RefCounted cleanup
	campaign_system = null
	game_state = null

func _disconnect_mission_signals() -> void:
	if not is_instance_valid(campaign_system):
		return
	
	if campaign_system.is_connected("mission_created", _on_mission_created):
		campaign_system.disconnect("mission_created", _on_mission_created)
	if campaign_system.is_connected("mission_started", _on_mission_signal):
		campaign_system.disconnect("mission_started", _on_mission_signal)
	if campaign_system.is_connected("mission_setup_complete", _on_mission_signal):
		campaign_system.disconnect("mission_setup_complete", _on_mission_signal)
	if campaign_system.is_connected("mission_completed", _on_mission_completed):
		campaign_system.disconnect("mission_completed", _on_mission_completed)

func get_signal_watcher() -> Node:
	return _signal_watcher

func clear_signal_watcher() -> void:
	_received_signals.clear()
	if is_instance_valid(campaign_system):
		_disconnect_mission_signals()

# Test function - must start with "test_"
func test_campaign_mission_flow() -> void:
	gut.p("Testing campaign mission flow...")
	
	# Start mission
	campaign_system.start_mission()
	
	# Wait for signals
	await get_tree().create_timer(0.5).timeout
	
	# Verify signals were received in correct order
	var expected_signals = ["mission_created", "mission_started", "mission_setup_complete"]
	for i in range(expected_signals.size()):
		var expected = expected_signals[i]
		assert_true(i < _received_signals.size(), "Should have enough signals")
		assert_eq(_received_signals[i], expected,
			"Signal %d should be %s" % [i, expected])
	
	# Verify mission state
	var mission = campaign_system.get_current_mission()
	assert_not_null(mission, "Mission should be created")
	assert_eq(campaign_system.get_mission_phase(), GameEnums.BattlePhase.SETUP,
		"Mission should be in setup phase")
	
	# Verify mission is in progress
	assert_true(campaign_system.is_mission_in_progress(), "Mission should be in progress")
	
	get_tree().process_frame
	
	# End mission and verify cleanup
	campaign_system.end_mission(true)
	
	# Wait for cleanup
	await get_tree().create_timer(0.1).timeout
	
	# Verify mission completed signal
	assert_true("mission_completed" in _received_signals,
		"Should have received mission_completed signal")
	
	# Verify cleanup
	assert_null(campaign_system.get_current_mission(), "Mission should be cleaned up")
	assert_false(campaign_system.is_mission_in_progress(), "Mission should not be in progress")
	
	# Verify signal count
	assert_eq(_received_signals.size(), expected_signals.size() + 1,
		"Should have received exactly %d signals" % (expected_signals.size() + 1))
	
	gut.p("Campaign mission flow test complete")
