@tool
extends GameTest

const CampaignUI = preload("res://src/scenes/campaign/CampaignUI.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

var game_state_manager
var ui

func before_each() -> void:
	await super.before_each()
	game_state_manager = GameStateManager.new()
	add_child(game_state_manager)
	track_test_node(game_state_manager)
	
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
	assert_not_null(ui, "UI should be created")
	assert_not_null(ui.resource_panel, "Resource panel should be initialized")
	assert_not_null(ui.action_panel, "Action panel should be initialized")
	assert_not_null(ui.phase_indicator, "Phase indicator should be initialized")
	assert_not_null(ui.event_log, "Event log should be initialized")
	assert_not_null(ui.phase_ui, "Phase UI should be initialized")

func test_resource_display() -> void:
	watch_signals(ui)
	
	# Set initial resources
	game_state_manager.set_credits(1000)
	game_state_manager.set_resource(GameEnums.ResourceType.FUEL, 50)
	
	# Verify UI updates
	assert_eq(ui.resource_panel.get_credits(), 1000, "Credits display should update")
	assert_eq(ui.resource_panel.get_resource(GameEnums.ResourceType.FUEL), 50, "Fuel display should update")
	assert_signal_emitted(ui, "resources_updated")

func test_phase_indicator() -> void:
	watch_signals(ui)
	
	game_state_manager.set_campaign_phase(GameEnums.CampaignPhase.SETUP)
	assert_eq(ui.phase_indicator.get_current_phase(), GameEnums.CampaignPhase.SETUP, "Phase indicator should update")
	assert_signal_emitted(ui, "phase_changed")
	
	game_state_manager.set_campaign_phase(GameEnums.CampaignPhase.UPKEEP)
	assert_eq(ui.phase_indicator.get_current_phase(), GameEnums.CampaignPhase.UPKEEP, "Phase indicator should update")
	assert_signal_emitted(ui, "phase_changed")

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
