@tool
extends "res://tests/fixtures/game_test.gd"

const UpkeepPhaseUI = preload("res://src/ui/screens/campaign/UpkeepPhaseUI.gd")

var upkeep_ui: UpkeepPhaseUI
var mock_game_state: GameState
var mock_phase_manager: Node

func before_each() -> void:
    mock_game_state = GameState.new()
    mock_phase_manager = Node.new()
    mock_phase_manager.name = "PhaseManager"
    
    add_child(mock_game_state)
    add_child(mock_phase_manager)
    
    upkeep_ui = UpkeepPhaseUI.new()
    add_child(upkeep_ui)
    await upkeep_ui.ready

func after_each() -> void:
    upkeep_ui.queue_free()
    mock_phase_manager.queue_free()
    mock_game_state.queue_free()

# Basic State Tests
func test_initial_state() -> void:
    assert_not_null(upkeep_ui, "UpkeepPhaseUI should be initialized")
    assert_false(upkeep_ui.is_phase_complete, "Phase should not start complete")

# Resource Management Tests
func test_resource_updates() -> void:
    # Setup mock campaign data
    mock_game_state.campaign = {
        "credits": 1000,
        "maintenance_cost": 100,
        "crew_members": [
            {"character_name": "Test Character", "upkeep_cost": 50}
        ]
    }
    
    upkeep_ui.setup(mock_game_state, mock_phase_manager)
    upkeep_ui._calculate_costs()
    
    assert_eq(upkeep_ui.total_maintenance_cost, 100,
        "Should calculate correct maintenance cost")
    assert_eq(upkeep_ui.total_crew_cost, 50,
        "Should calculate correct crew cost")
    assert_eq(upkeep_ui.total_cost, 150,
        "Should calculate correct total cost")

# UI Interaction Tests
func test_pay_upkeep_button() -> void:
    watch_signals(upkeep_ui)
    
    mock_game_state.campaign = {
        "credits": 1000,
        "maintenance_cost": 100
    }
    
    upkeep_ui.setup(mock_game_state, mock_phase_manager)
    upkeep_ui._on_pay_upkeep_pressed()
    
    assert_eq(mock_game_state.campaign.credits, 900,
        "Should deduct upkeep costs from credits")
    assert_true(upkeep_ui.is_phase_complete,
        "Phase should be complete after paying upkeep")

# Error Cases Tests
func test_insufficient_funds() -> void:
    mock_game_state.campaign = {
        "credits": 50,
        "maintenance_cost": 100
    }
    
    upkeep_ui.setup(mock_game_state, mock_phase_manager)
    upkeep_ui._on_pay_upkeep_pressed()
    
    assert_eq(mock_game_state.campaign.credits, 50,
        "Should not deduct credits when insufficient")
    assert_false(upkeep_ui.is_phase_complete,
        "Phase should not complete with insufficient funds")

# Event Handler Tests
func test_phase_events() -> void:
    watch_signals(upkeep_ui)
    
    upkeep_ui.setup(mock_game_state, mock_phase_manager)
    upkeep_ui._on_phase_started()
    
    assert_false(upkeep_ui.is_phase_complete,
        "Phase should reset on start")
    assert_true(upkeep_ui.visible,
        "UI should be visible when phase starts")

# Performance Tests
func test_rapid_cost_calculations() -> void:
    mock_game_state.campaign = {
        "credits": 1000,
        "maintenance_cost": 100,
        "crew_members": []
    }
    
    var start_time := Time.get_ticks_msec()
    
    for i in range(100):
        mock_game_state.campaign.crew_members.append({
            "character_name": "Test Character %d" % i,
            "upkeep_cost": 50
        })
        upkeep_ui._calculate_costs()
    
    var duration := Time.get_ticks_msec() - start_time
    assert_true(duration < 1000,
        "Should handle rapid cost calculations efficiently")

# Cleanup Tests
func test_cleanup() -> void:
    upkeep_ui.setup(mock_game_state, mock_phase_manager)
    upkeep_ui.cleanup()
    
    assert_false(upkeep_ui.is_phase_complete,
        "Should reset phase completion on cleanup")
    assert_false(upkeep_ui.visible,
        "Should hide UI on cleanup")