@tool
extends "res://tests/fixtures/game_test.gd"
class_name TestCampaignMissionFlow

const FiveParsecsCampaignSystem := preload("res://src/core/campaign/CampaignSystem.gd")

var campaign_system: FiveParsecsCampaignSystem
var game_state: Node

# Signal tracking
var _received_signals: Array = []

func before_all() -> void:
	super.before_all()

func after_all() -> void:
	super.after_all()

func before_each() -> void:
	super.before_each()
	gut.p("Setting up test environment...")
	
	# Initialize game state using framework method
	game_state = create_test_game_state()
	add_child_autofree(game_state)
	
	# Load test campaign before validation
	load_test_campaign(game_state)
	assert_valid_game_state(game_state)
	get_tree().process_frame
	
	# Set up campaign system
	campaign_system = FiveParsecsCampaignSystem.new()
	add_child_autofree(campaign_system)
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
	
	# Let parent handle cleanup first
	super.after_each()
	
	# Then handle node cleanup
	if is_instance_valid(game_state):
		remove_child(game_state)
		game_state.queue_free()
	if is_instance_valid(campaign_system):
		remove_child(campaign_system)
		campaign_system.queue_free()
	
	# Wait for nodes to be freed
	await get_tree().process_frame
	
	# Clear references to allow RefCounted cleanup
	campaign_system = null
	game_state = null
	
	# Clear any tracked resources
	_tracked_resources.clear()

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
	# Start mission
	campaign_system.start_mission()
	
	# Wait for signals
	await get_tree().create_timer(0.5).timeout
	
	# Verify signals were received in correct order
	var expected_signals = ["mission_created", "mission_started", "mission_setup_complete"]
	for expected in expected_signals:
		assert_true(expected in _received_signals,
			"Should have received %s signal" % expected)
	
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
