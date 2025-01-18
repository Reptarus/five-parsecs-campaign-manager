@tool
extends "res://tests/performance/perf_test_base.gd"

const CampaignUI := preload("res://src/scenes/campaign/CampaignUI.gd")
const TestHelper := preload("res://tests/fixtures/test_helper.gd")
const GameState := preload("res://src/core/state/GameState.gd")

var game_state: GameState
var ui: CampaignUI

func before_each() -> void:
	super.before_each()
	game_state = _create_test_game_state()
	ui = _create_test_ui()
	await ui.ready
	ui.game_state = game_state

func after_each() -> void:
	super.after_each()
	game_state = null
	if is_instance_valid(ui):
		ui.queue_free()
	ui = null

# Helper Functions
func _create_test_game_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	var test_state := TestHelper.setup_test_game_state()
	state.load_state(test_state)
	return state

func _create_test_ui() -> CampaignUI:
	var scene := CampaignUI.new()
	add_child(scene)
	return scene

# Test Cases - UI Initialization
func test_ui_initialization() -> void:
	assert_not_null(ui, "UI should be created")
	assert_not_null(ui.resource_panel, "Resource panel should be initialized")
	assert_not_null(ui.action_panel, "Action panel should be initialized")
	assert_not_null(ui.phase_indicator, "Phase indicator should be initialized")
	assert_not_null(ui.event_log, "Event log should be initialized")
	assert_not_null(ui.phase_ui, "Phase UI should be initialized")

# Test Cases - Resource Display
func test_resource_display() -> void:
	# Set initial resources
	game_state.modify_credits(1000)
	game_state.modify_resource(GameEnums.ResourceType.FUEL, 50)
	
	# Wait for UI update and check values
	assert_true(
		await TestHelper.wait_for_signal(ui, "resource_updated", 1.0),
		"Resource update signal should be emitted"
	)
	
	# Check UI values through resource panel
	assert_eq(ui.resource_panel.get_resource_value(GameEnums.ResourceType.CREDITS), 1000, "Credits display should match game state")
	assert_eq(ui.resource_panel.get_resource_value(GameEnums.ResourceType.FUEL), 50, "Fuel display should match game state")

# Test Cases - Phase Display
func test_phase_display() -> void:
	game_state.set_campaign_phase(GameEnums.CampaignPhase.SETUP)
	
	assert_true(
		await TestHelper.wait_for_signal(ui, "phase_changed", 1.0),
		"Phase change signal should be emitted"
	)
	
	assert_eq(ui._current_phase, GameEnums.CampaignPhase.SETUP, "Phase should be updated")
	assert_true(ui.phase_indicator.is_visible(), "Phase indicator should be visible")

# Test Cases - Event Log
func test_event_log() -> void:
	var event_data := {
		"type": "resource_changed",
		"resource": GameEnums.ResourceType.FUEL,
		"old_value": 50,
		"new_value": 75
	}
	
	ui.emit_signal("event_occurred", event_data)
	
	assert_true(
		await TestHelper.wait_for_signal(ui, "event_occurred", 1.0),
		"Event signal should be emitted"
	)
	
	assert_true(ui.event_log.has_event(event_data), "Event should be logged")

# Test Cases - Performance
func test_ui_update_performance() -> void:
	var execution_time := time_block("UI Updates", func():
		for i in range(10):
			game_state.modify_credits(i * 100)
			game_state.modify_resource(GameEnums.ResourceType.FUEL, i * 5)
			await TestHelper.wait_for_signal(ui, "resource_updated", 0.1)
	)
	
	print("UI update time (10 updates): %.3f seconds" % execution_time)
	assert_lt(execution_time, PERFORMANCE_THRESHOLD, "UI updates should complete within threshold")

func test_phase_transition_performance() -> void:
	var execution_time := time_block("Phase Transitions", func():
		for phase in [
			GameEnums.CampaignPhase.SETUP,
			GameEnums.CampaignPhase.UPKEEP,
			GameEnums.CampaignPhase.STORY,
			GameEnums.CampaignPhase.CAMPAIGN,
			GameEnums.CampaignPhase.BATTLE_SETUP
		]:
			game_state.set_campaign_phase(phase)
			await TestHelper.wait_for_signal(ui, "phase_changed", 0.1)
	)
	
	print("Phase transition time (5 phases): %.3f seconds" % execution_time)
	assert_lt(execution_time, PERFORMANCE_THRESHOLD, "Phase transitions should complete within threshold")