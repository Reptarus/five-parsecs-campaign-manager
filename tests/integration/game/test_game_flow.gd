@tool
extends "res://tests/fixtures/base/game_test.gd"

const GameStateManager: GDScript = preload("res://src/core/managers/GameStateManager.gd")

# Type-safe instance variables
var game_state_manager: GameStateManager = null
var _test_game_state: Node = null

func before_all() -> void:
	super.before_all()

func after_all() -> void:
	super.after_all()

func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	_test_game_state = create_test_game_state()
	if not _test_game_state:
		push_error("Failed to create test game state")
		return
		
	add_child_autofree(_test_game_state)
	if not _test_game_state:
		push_error("Failed to add game state to scene tree")
		return
		
	verify_state(_test_game_state, {
		"is_inside_tree": true,
		"is_processing": true
	})
	
	# Initialize game state manager
	game_state_manager = GameStateManager.new()
	if not game_state_manager:
		push_error("Failed to create game state manager")
		return
		
	game_state_manager.game_state = _test_game_state
	add_child_autofree(game_state_manager)
	if not game_state_manager:
		push_error("Failed to add game state manager to scene tree")
		return
		
	_signal_watcher.watch_signals(game_state_manager)
	
	await stabilize_engine()

func after_each() -> void:
	# Clean up nodes first
	if is_instance_valid(_test_game_state):
		remove_child(_test_game_state)
		_test_game_state.queue_free()
	
	if is_instance_valid(game_state_manager):
		remove_child(game_state_manager)
		game_state_manager.queue_free()
	
	# Wait for nodes to be freed
	await get_tree().process_frame
	
	# Clear references
	game_state_manager = null
	_test_game_state = null
	
	# Let parent handle remaining cleanup
	await super.after_each()
	
	# Clear any tracked resources
	_cleanup_tracked_resources()

func test_initial_state() -> void:
	assert_not_null(game_state_manager, "Game state manager should be initialized")
	assert_not_null(game_state_manager.game_state, "Game state should be set")
	
	var phase: int = _call_node_method_int(game_state_manager, "get_campaign_phase", [], GameEnums.FiveParcsecsCampaignPhase.NONE)
	assert_eq(phase, GameEnums.FiveParcsecsCampaignPhase.NONE, "Should start in NONE phase")
	
	verify_state(_test_game_state, {
		"is_inside_tree": true,
		"is_processing": true
	})

func test_state_transition() -> void:
	# Change to setup phase
	_call_node_method_bool(game_state_manager, "set_campaign_phase", [GameEnums.FiveParcsecsCampaignPhase.SETUP])
	var phase_changed: bool = await assert_async_signal(game_state_manager, "phase_changed")
	assert_true(phase_changed, "Phase changed signal should be emitted")
	
	var current_phase: int = _call_node_method_int(game_state_manager, "get_campaign_phase", [], GameEnums.FiveParcsecsCampaignPhase.NONE)
	assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.SETUP, "Should transition to SETUP phase")
	
	# Change back to none phase
	_call_node_method_bool(game_state_manager, "set_campaign_phase", [GameEnums.FiveParcsecsCampaignPhase.NONE])
	phase_changed = await assert_async_signal(game_state_manager, "phase_changed")
	assert_true(phase_changed, "Phase changed signal should be emitted")
	
	current_phase = _call_node_method_int(game_state_manager, "get_campaign_phase", [], GameEnums.FiveParcsecsCampaignPhase.NONE)
	assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.NONE, "Should return to NONE phase")

func test_invalid_state_transition() -> void:
	# Try to transition to the same phase
	_call_node_method_bool(game_state_manager, "set_campaign_phase", [GameEnums.FiveParcsecsCampaignPhase.NONE])
	var phase_changed: bool = await assert_async_signal(game_state_manager, "phase_changed", 0.5) # Short timeout since we expect no signal
	assert_false(phase_changed, "Phase changed signal should not be emitted")
	
	var current_phase: int = _call_node_method_int(game_state_manager, "get_campaign_phase", [], GameEnums.FiveParcsecsCampaignPhase.NONE)
	assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.NONE, "Should stay in NONE phase")
	
	# Try to transition to an invalid phase
	_call_node_method_bool(game_state_manager, "set_campaign_phase", [-1])
	phase_changed = await assert_async_signal(game_state_manager, "phase_changed", 0.5) # Short timeout since we expect no signal
	assert_false(phase_changed, "Phase changed signal should not be emitted")
	
	current_phase = _call_node_method_int(game_state_manager, "get_campaign_phase", [], GameEnums.FiveParcsecsCampaignPhase.NONE)
	assert_eq(current_phase, GameEnums.FiveParcsecsCampaignPhase.NONE, "Should stay in NONE phase")
