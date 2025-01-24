@tool
extends "res://tests/fixtures/game_test.gd"

const CampaignCreationUI = preload("res://src/ui/screens/campaign/CampaignCreationUI.gd")

var creation_ui: CampaignCreationUI
var mock_game_state: GameState

func before_each() -> void:
    mock_game_state = GameState.new()
    add_child(mock_game_state)
    
    creation_ui = CampaignCreationUI.new()
    add_child(creation_ui)
    await creation_ui.ready

func after_each() -> void:
    creation_ui.queue_free()
    mock_game_state.queue_free()

# Basic State Tests
func test_initial_state() -> void:
    assert_not_null(creation_ui, "CampaignCreationUI should be initialized")
    assert_false(creation_ui.is_campaign_valid,
        "Campaign should not be valid initially")

# Campaign Settings Tests
func test_campaign_settings() -> void:
    creation_ui.campaign_name_input.text = "Test Campaign"
    creation_ui.difficulty_option.selected = GameEnums.DifficultyLevel.NORMAL
    creation_ui._on_settings_changed()
    
    assert_true(creation_ui.is_campaign_valid,
        "Campaign should be valid with name and difficulty")
    assert_eq(creation_ui.campaign_settings.name, "Test Campaign",
        "Should store campaign name")
    assert_eq(creation_ui.campaign_settings.difficulty, GameEnums.DifficultyLevel.NORMAL,
        "Should store difficulty setting")

# Validation Tests
func test_campaign_validation() -> void:
    # Test empty name
    creation_ui.campaign_name_input.text = ""
    creation_ui._on_settings_changed()
    assert_false(creation_ui.is_campaign_valid,
        "Campaign should be invalid with empty name")
    
    # Test valid name
    creation_ui.campaign_name_input.text = "Valid Name"
    creation_ui._on_settings_changed()
    assert_true(creation_ui.is_campaign_valid,
        "Campaign should be valid with proper name")

# Creation Flow Tests
func test_campaign_creation_flow() -> void:
    watch_signals(creation_ui)
    
    # Setup valid campaign
    creation_ui.campaign_name_input.text = "Test Campaign"
    creation_ui.difficulty_option.selected = GameEnums.DifficultyLevel.NORMAL
    creation_ui._on_settings_changed()
    
    # Test creation
    creation_ui._on_create_pressed()
    
    assert_signal_emitted(creation_ui, "campaign_created")
    assert_not_null(mock_game_state.campaign,
        "Should create campaign in game state")

# UI Interaction Tests
func test_ui_interactions() -> void:
    watch_signals(creation_ui)
    
    # Test difficulty change
    creation_ui.difficulty_option._on_item_selected(GameEnums.DifficultyLevel.HARD)
    assert_eq(creation_ui.campaign_settings.difficulty, GameEnums.DifficultyLevel.HARD,
        "Should update difficulty setting")
    
    # Test name change
    creation_ui.campaign_name_input.text = "New Name"
    creation_ui.campaign_name_input.text_changed.emit("New Name")
    assert_eq(creation_ui.campaign_settings.name, "New Name",
        "Should update campaign name")

# Error Cases Tests
func test_error_cases() -> void:
    # Test invalid characters in name
    creation_ui.campaign_name_input.text = "Test/Campaign"
    creation_ui._on_settings_changed()
    assert_false(creation_ui.is_campaign_valid,
        "Should reject names with invalid characters")
    
    # Test extremely long name
    creation_ui.campaign_name_input.text = "A".repeat(100)
    creation_ui._on_settings_changed()
    assert_false(creation_ui.is_campaign_valid,
        "Should reject extremely long names")

# Navigation Tests
func test_navigation() -> void:
    watch_signals(get_tree())
    
    creation_ui._on_back_pressed()
    assert_signal_emitted(get_tree(), "change_scene_to_file")

# Performance Tests
func test_rapid_input_changes() -> void:
    var start_time := Time.get_ticks_msec()
    
    for i in range(100):
        creation_ui.campaign_name_input.text = "Test Campaign %d" % i
        creation_ui._on_settings_changed()
    
    var duration := Time.get_ticks_msec() - start_time
    assert_true(duration < 1000,
        "Should handle rapid input changes efficiently")

# Cleanup Tests
func test_cleanup() -> void:
    creation_ui.campaign_name_input.text = "Test"
    creation_ui.difficulty_option.selected = GameEnums.DifficultyLevel.HARD
    
    creation_ui._reset_ui()
    
    assert_eq(creation_ui.campaign_name_input.text, "",
        "Should clear campaign name")
    assert_eq(creation_ui.difficulty_option.selected, GameEnums.DifficultyLevel.NORMAL,
        "Should reset difficulty to normal")