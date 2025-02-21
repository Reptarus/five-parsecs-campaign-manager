@tool
extends "res://tests/fixtures/game_test.gd"

const CampaignUI: GDScript = preload("res://src/scenes/campaign/CampaignUI.gd")
const GameStateManager: GDScript = preload("res://src/core/managers/GameStateManager.gd")

var game_state_manager: Node = null
var ui: Node = null

func before_each() -> void:
	await super.before_each()
	
	game_state_manager = GameStateManager.new()
	if not game_state_manager:
		push_error("Failed to create game state manager instance")
		return
	add_child(game_state_manager)
	track_test_node(game_state_manager)
	await get_tree().process_frame
	
	ui = CampaignUI.new()
	if not ui:
		push_error("Failed to create campaign UI instance")
		return
	add_child(ui)
	track_test_node(ui)
	await ui.ready
	
	if not game_state_manager:
		push_error("Game state manager not initialized")
		return
	ui.game_state_manager = game_state_manager
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	game_state_manager = null
	ui = null

func test_initial_state() -> void:
	assert_not_null(game_state_manager, "Game state manager should be initialized")
	
	var phase: int = _get_property_safe(game_state_manager, "campaign_phase", GameEnums.FiveParcsecsCampaignPhase.NONE)
	assert_eq(phase, GameEnums.FiveParcsecsCampaignPhase.NONE, "Should start in NONE phase")
	
	var difficulty: int = _get_property_safe(game_state_manager, "difficulty_level", GameEnums.DifficultyLevel.NORMAL)
	assert_eq(difficulty, GameEnums.DifficultyLevel.NORMAL, "Should start with NORMAL difficulty")
	
	var game_state: int = _get_property_safe(game_state_manager, "game_state", GameEnums.GameState.NONE)
	assert_eq(game_state, GameEnums.GameState.NONE, "Should start in NONE game state")

func test_resource_display() -> void:
	if not ui:
		push_error("UI not initialized")
		return
		
	watch_signals(ui)
	
	# Set initial resources
	if not game_state_manager:
		push_error("Game state manager not initialized")
		return
		
	_call_node_method(game_state_manager, "set_credits", [1000])
	_call_node_method(game_state_manager, "set_resource", [GameEnums.ResourceType.FUEL, 50])
	
	# Verify UI updates
	var resource_panel: Node = _get_property_safe(ui, "resource_panel")
	if not resource_panel:
		push_error("Resource panel not found")
		return
		
	var credits: int = _call_node_method_int(resource_panel, "get_credits")
	assert_eq(credits, 1000, "Credits display should update")
	
	var fuel: int = _call_node_method_int(resource_panel, "get_resource", [GameEnums.ResourceType.FUEL])
	assert_eq(fuel, 50, "Fuel display should update")
	
	verify_signal_emitted(ui, "resources_updated", "Resource update signal should be emitted")

func test_campaign_phase_transitions() -> void:
	if not game_state_manager:
		push_error("Game state manager not initialized")
		return
		
	watch_signals(game_state_manager)
	
	var valid_phases: Array[int] = [
		GameEnums.FiveParcsecsCampaignPhase.SETUP,
		GameEnums.FiveParcsecsCampaignPhase.UPKEEP,
		GameEnums.FiveParcsecsCampaignPhase.STORY,
		GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN,
		GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP,
		GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION,
		GameEnums.FiveParcsecsCampaignPhase.ADVANCEMENT,
		GameEnums.FiveParcsecsCampaignPhase.TRADE
	]
	
	for phase in valid_phases:
		_call_node_method(game_state_manager, "set_campaign_phase", [phase])
		
		var current_phase: int = _get_property_safe(game_state_manager, "campaign_phase", -1)
		assert_eq(current_phase, phase, "Should transition to %s phase" % GameEnums.PHASE_NAMES[phase])
		
		verify_signal_emitted(game_state_manager, "campaign_phase_changed", "Phase change signal should be emitted")
		
		var phase_name: String = _call_node_method(game_state_manager, "get_phase_name").get_string()
		assert_eq(phase_name, GameEnums.PHASE_NAMES[phase], "Should return correct phase name")
		
		var phase_description: String = _call_node_method(game_state_manager, "get_phase_description").get_string()
		assert_eq(phase_description, GameEnums.PHASE_DESCRIPTIONS[phase], "Should return correct phase description")

func test_event_log() -> void:
	if not ui:
		push_error("UI not initialized")
		return
		
	watch_signals(ui)
	
	var test_event: Dictionary = {
		"type": "test",
		"message": "Test event",
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var event_log: Node = _get_property_safe(ui, "event_log")
	if not event_log:
		push_error("Event log not found")
		return
		
	_call_node_method(event_log, "add_event", [test_event])
	
	var event_count: int = _call_node_method_int(event_log, "get_event_count")
	assert_eq(event_count, 1, "Event should be added to log")
	
	var last_event: Dictionary = _call_node_method_dict(event_log, "get_last_event")
	assert_eq(last_event.get("message", ""), "Test event", "Event message should be correct")
	
	verify_signal_emitted(ui, "event_logged", "Event logged signal should be emitted")

func test_action_panel() -> void:
	if not ui:
		push_error("UI not initialized")
		return
		
	watch_signals(ui)
	
	var action_panel: Node = _get_property_safe(ui, "action_panel")
	if not action_panel:
		push_error("Action panel not found")
		return
		
	_call_node_method(action_panel, "enable_action", ["test_action"])
	var is_enabled: bool = _call_node_method_bool(action_panel, "is_action_enabled", ["test_action"])
	assert_true(is_enabled, "Action should be enabled")
	verify_signal_emitted(ui, "action_state_changed", "Action state change signal should be emitted")
	
	_call_node_method(action_panel, "disable_action", ["test_action"])
	is_enabled = _call_node_method_bool(action_panel, "is_action_enabled", ["test_action"])
	assert_false(is_enabled, "Action should be disabled")
	verify_signal_emitted(ui, "action_state_changed", "Action state change signal should be emitted")
