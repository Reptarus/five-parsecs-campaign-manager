@tool
extends "res://tests/fixtures/game_test.gd"

const CampaignUI := preload("res://src/scenes/campaign/CampaignUI.gd")

# Test variables
var game_state: Node # Using Node type since GameState extends Node
var ui: Node # Using Node type since CampaignUI extends Node

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	game_state = create_test_game_state()
	add_child(game_state)
	track_test_node(game_state)
	
	ui = CampaignUI.new()
	add_child(ui)
	track_test_node(ui)
	await ui.ready
	
	ui.game_state = game_state
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	game_state = null
	ui = null

# Test Methods
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
	game_state.credits = 1000
	game_state.resources[GameEnums.ResourceType.FUEL] = 50
	
	# Verify UI updates
	assert_eq(ui.resource_panel.credits_label.text, "1000", "Credits display should update")
	assert_eq(ui.resource_panel.fuel_label.text, "50", "Fuel display should update")
	assert_signal_emitted(ui, "resources_updated")

func test_phase_indicator() -> void:
	watch_signals(ui)
	
	game_state.current_phase = GameEnums.CampaignPhase.SETUP
	assert_eq(ui.phase_indicator.current_phase, GameEnums.CampaignPhase.SETUP, "Phase indicator should update")
	assert_signal_emitted(ui, "phase_changed")
	
	game_state.current_phase = GameEnums.CampaignPhase.UPKEEP
	assert_eq(ui.phase_indicator.current_phase, GameEnums.CampaignPhase.UPKEEP, "Phase indicator should update")
	assert_signal_emitted(ui, "phase_changed")

func test_event_log() -> void:
	watch_signals(ui)
	
	var test_event = {
		"type": "test",
		"message": "Test event"
	}
	ui.event_log.add_event(test_event)
	
	assert_eq(ui.event_log.events.size(), 1, "Event should be added to log")
	assert_eq(ui.event_log.events[0].message, "Test event", "Event message should be correct")
	assert_signal_emitted(ui, "event_logged")
