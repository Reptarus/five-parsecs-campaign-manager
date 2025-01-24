@tool
extends "res://tests/fixtures/game_test.gd"

const CampaignDashboardUI = preload("res://src/ui/screens/campaign/CampaignDashboard.gd")

var dashboard: CampaignDashboardUI
var mock_game_state: GameState

func before_each() -> void:
    mock_game_state = GameState.new()
    add_child(mock_game_state)
    
    dashboard = CampaignDashboardUI.new()
    add_child(dashboard)
    await dashboard.ready

func after_each() -> void:
    dashboard.queue_free()
    mock_game_state.queue_free()

# Basic State Tests
func test_initial_state() -> void:
    assert_not_null(dashboard.game_state, "Game state should be initialized")
    assert_not_null(dashboard.phase_manager, "Phase manager should be initialized")
    assert_eq(dashboard.phase_manager.current_phase, GameEnums.CampaignPhase.UPKEEP,
        "Should start in upkeep phase")

# Phase Transition Tests
func test_phase_transitions() -> void:
    watch_signals(dashboard.phase_manager)
    
    dashboard._on_next_phase_pressed()
    assert_signal_emitted(dashboard.phase_manager, "phase_changed")
    assert_eq(dashboard.phase_manager.current_phase, GameEnums.CampaignPhase.STORY,
        "Should transition to story phase")
    
    dashboard._on_next_phase_pressed()
    assert_eq(dashboard.phase_manager.current_phase, GameEnums.CampaignPhase.CAMPAIGN,
        "Should transition to campaign phase")

# UI Update Tests
func test_ui_updates() -> void:
    # Setup mock campaign data
    mock_game_state.campaign = {
        "credits": 1000,
        "story_points": 5,
        "crew_members": [
            {"character_name": "Test Character"}
        ]
    }
    
    dashboard._update_ui()
    
    assert_eq(dashboard.credits_label.text, "Credits: 1000",
        "Credits label should update")
    assert_eq(dashboard.story_points_label.text, "Story Points: 5",
        "Story points label should update")
    assert_eq(dashboard.crew_list.get_item_count(), 1,
        "Crew list should show one member")

# Phase Panel Tests
func test_phase_panel_creation() -> void:
    var panel = dashboard._create_phase_panel(GameEnums.CampaignPhase.UPKEEP)
    assert_not_null(panel, "Should create upkeep phase panel")
    panel.queue_free()
    
    panel = dashboard._create_phase_panel(GameEnums.CampaignPhase.STORY)
    assert_not_null(panel, "Should create story phase panel")
    panel.queue_free()

# Event Handler Tests
func test_phase_event_handling() -> void:
    watch_signals(dashboard)
    
    dashboard._on_phase_event({"type": "UPKEEP_STARTED"})
    assert_true(dashboard.next_phase_button.visible,
        "Next phase button should be visible after upkeep start")
    
    dashboard._on_phase_completed()
    assert_false(dashboard.next_phase_button.disabled,
        "Next phase button should be enabled after phase completion")

# Navigation Tests
func test_navigation_buttons() -> void:
    watch_signals(get_tree())
    
    dashboard._on_manage_crew_pressed()
    assert_signal_emitted(get_tree(), "change_scene_to_file")
    
    dashboard._on_quit_pressed()
    assert_signal_emitted(get_tree(), "change_scene_to_file")

# Performance Tests
func test_rapid_phase_transitions() -> void:
    var start_time := Time.get_ticks_msec()
    
    for i in range(10):
        dashboard._on_next_phase_pressed()
        await get_tree().process_frame
    
    var duration := Time.get_ticks_msec() - start_time
    assert_true(duration < 1000,
        "Should handle rapid phase transitions efficiently")

# Error Boundary Tests
func test_invalid_phase_transitions() -> void:
    dashboard.phase_manager.current_phase = GameEnums.CampaignPhase.NONE
    dashboard._on_next_phase_pressed()
    assert_eq(dashboard.phase_manager.current_phase, GameEnums.CampaignPhase.NONE,
        "Should not transition from invalid phase")

# Save/Load Tests
func test_save_load_operations() -> void:
    watch_signals(mock_game_state)
    
    dashboard._on_save_pressed()
    assert_signal_emitted(mock_game_state, "save_campaign")
    
    dashboard._on_load_pressed()
    assert_signal_emitted(get_tree(), "change_scene_to_file")