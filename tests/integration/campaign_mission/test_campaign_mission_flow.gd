@tool
extends GameTest

const FiveParsecsCampaignSystem := preload("res://src/core/campaign/CampaignSystem.gd")

var campaign_system: FiveParsecsCampaignSystem
var game_state: Node

# Signal tracking
var _received_signals: Array = []

func before_all() -> void:
	super.before_all()

func after_all() -> void:
	super.after_all()

# Helper function to load test campaign data
func load_test_campaign(state: Node) -> void:
	if not state:
		push_error("Cannot load campaign: game state is null")
		return
		
	var campaign := create_test_campaign()
	if not campaign:
		push_error("Failed to create test campaign")
		return
		
	_set_state_property(state, "current_campaign", campaign)
	_set_state_property(state, "difficulty_level", GameEnums.DifficultyLevel.NORMAL)
	_set_state_property(state, "enable_permadeath", true)
	_set_state_property(state, "use_story_track", true)
	_set_state_property(state, "auto_save_enabled", true)

func before_each() -> void:
	super.before_each()
	print("Setting up test environment...")
	
	# Initialize game state using framework method
	game_state = create_test_game_state()
	add_child_autofree(game_state)
	track_test_node(game_state)
	
	# Load test campaign before validation
	load_test_campaign(game_state)
	assert_valid_game_state(game_state)
	
	# Set up campaign system
	campaign_system = FiveParsecsCampaignSystem.new()
	add_child_autofree(campaign_system)
	track_test_node(campaign_system)
	_connect_mission_signals()
	campaign_system.initialize(game_state)
	
	print("Test environment setup complete")

func _connect_mission_signals() -> void:
	if not campaign_system:
		push_error("Cannot connect signals: campaign system is null")
		return
		
	campaign_system.mission_created.connect(_on_mission_created)
	campaign_system.mission_started.connect(_on_mission_signal.bind("mission_started"))
	campaign_system.mission_setup_complete.connect(_on_mission_signal.bind("mission_setup_complete"))
	campaign_system.mission_completed.connect(_on_mission_completed)

func _on_mission_created(mission: Node) -> void:
	_received_signals.append("mission_created")
	track_test_node(mission) # Track the created mission node
	print("Mission created: " + str(mission))
	assert_not_null(mission, "Mission node should be created")

func _on_mission_signal(signal_name: String) -> void:
	_received_signals.append(signal_name)
	print("Received signal: " + signal_name)
	assert_true(signal_name in ["mission_started", "mission_setup_complete"],
		"Signal should be a valid mission signal")

func _on_mission_completed(success: bool) -> void:
	_received_signals.append("mission_completed")
	print("Mission completed with success: %s" % success)

func after_each() -> void:
	_disconnect_mission_signals()
	if is_instance_valid(campaign_system):
		campaign_system.queue_free()
	if is_instance_valid(game_state):
		game_state.queue_free()
	campaign_system = null
	game_state = null
	_received_signals.clear()
	super.after_each()

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

func clear_signal_watcher() -> void:
	_received_signals.clear()
	if is_instance_valid(campaign_system):
		_disconnect_mission_signals()

# Test function - must start with "test_"
func test_campaign_mission_flow() -> void:
	print("Testing campaign mission flow...")
	
	# Verify initial state
	assert_false(campaign_system.is_mission_in_progress(),
		"No mission should be in progress initially")
	assert_null(campaign_system.get_current_mission(),
		"No current mission should exist initially")
	
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
	
	await get_tree().process_frame
	
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
	
	print("Campaign mission flow test complete")
