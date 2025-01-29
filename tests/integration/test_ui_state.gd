@tool
extends "res://tests/fixtures/game_test.gd"

const CampaignUI = preload("res://src/scenes/campaign/CampaignUI.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

var game_state_manager: GameStateManager
var ui

func before_each() -> void:
	await super.before_each()
	game_state_manager = GameStateManager.new()
	add_child(game_state_manager)
	track_test_node(game_state_manager)
	await get_tree().process_frame
	
	ui = CampaignUI.new()
	add_child(ui)
	track_test_node(ui)
	await ui.ready
	
	ui.game_state_manager = game_state_manager
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	game_state_manager = null
	ui = null

func test_initial_state() -> void:
	assert_not_null(game_state_manager, "Game state manager should be initialized")
	assert_eq(game_state_manager.campaign_phase, GameEnums.FiveParcsecsCampaignPhase.NONE, "Should start in NONE phase")
	assert_eq(game_state_manager.difficulty_level, GameEnums.DifficultyLevel.NORMAL, "Should start with NORMAL difficulty")
	assert_eq(game_state_manager.game_state, GameEnums.GameState.NONE, "Should start in NONE game state")

func test_resource_display() -> void:
	watch_signals(ui)
	
	# Set initial resources
	game_state_manager.set_credits(1000)
	game_state_manager.set_resource(GameEnums.ResourceType.FUEL, 50)
	
	# Verify UI updates
	assert_eq(ui.resource_panel.get_credits(), 1000, "Credits display should update")
	assert_eq(ui.resource_panel.get_resource(GameEnums.ResourceType.FUEL), 50, "Fuel display should update")
	assert_signal_emitted(ui, "resources_updated")

func test_campaign_phase_transitions() -> void:
	watch_signals(game_state_manager)
	
	var valid_phases = [
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
		game_state_manager.set_campaign_phase(phase)
		assert_eq(game_state_manager.campaign_phase, phase, "Should transition to %s phase" % GameEnums.PHASE_NAMES[phase])
		assert_signal_emitted(game_state_manager, "campaign_phase_changed")
		assert_eq(game_state_manager.get_phase_name(), GameEnums.PHASE_NAMES[phase], "Should return correct phase name")
		assert_eq(game_state_manager.get_phase_description(), GameEnums.PHASE_DESCRIPTIONS[phase], "Should return correct phase description")

func test_event_log() -> void:
	watch_signals(ui)
	
	var test_event = {
		"type": "test",
		"message": "Test event",
		"timestamp": Time.get_unix_time_from_system()
	}
	ui.event_log.add_event(test_event)
	
	assert_eq(ui.event_log.get_event_count(), 1, "Event should be added to log")
	var last_event = ui.event_log.get_last_event()
	assert_eq(last_event.message, "Test event", "Event message should be correct")
	assert_signal_emitted(ui, "event_logged")

func test_action_panel() -> void:
	watch_signals(ui)
	
	ui.action_panel.enable_action("test_action")
	assert_true(ui.action_panel.is_action_enabled("test_action"), "Action should be enabled")
	assert_signal_emitted(ui, "action_state_changed")
	
	ui.action_panel.disable_action("test_action")
	assert_false(ui.action_panel.is_action_enabled("test_action"), "Action should be disabled")
	assert_signal_emitted(ui, "action_state_changed")
