extends "res://tests/base_test.gd"

# Load required scripts
var GameStateManager = load("res://src/core/state_machines/GameStateManager.gd")
var CampaignManager = load("res://src/data/resources/Core/Managers/CampaignManager.gd")
var UIManager = load("res://src/ui/screens/UIManager.gd")

# Test variables
var state_manager: Node
var campaign_manager: Node
var ui_manager: Node

func before_all():
    super.before_all()
    state_manager = GameStateManager.new()
    campaign_manager = CampaignManager.new()
    ui_manager = UIManager.new()
    add_child(state_manager)
    add_child(campaign_manager)
    add_child(ui_manager)

func after_all():
    super.after_all()
    await cleanup_node(state_manager)
    await cleanup_node(campaign_manager)
    await cleanup_node(ui_manager)

func before_each():
    super.before_each()
    # Reset game state before each test
    state_manager.reset_state()
    campaign_manager.reset()
    if ui_manager.has_method("reset"):
        ui_manager.reset()

# Game Start Tests
func test_new_game_flow():
    # Start new game
    var game_started = state_manager.start_new_game()
    assert_true(game_started, "Should successfully start new game")
    assert_eq(state_manager.get_current_state(), "CAMPAIGN_SETUP", "Should be in campaign setup state")
    
    # Create character
    var character = campaign_manager.create_character()
    assert_not_null(character, "Should create character")
    assert_true(character.is_valid(), "Character should be valid")

# Campaign Flow Tests
func test_campaign_progression():
    state_manager.start_new_game()
    campaign_manager.create_character()
    
    # Start campaign
    campaign_manager.start_campaign()
    assert_eq(state_manager.get_current_state(), "CAMPAIGN_RUNNING", "Should be in campaign running state")
    
    # Generate mission
    var mission = campaign_manager.generate_mission()
    assert_not_null(mission, "Should generate mission")
    assert_true(mission.is_valid(), "Mission should be valid")

# Battle Flow Tests
func test_battle_sequence():
    state_manager.start_new_game()
    campaign_manager.create_character()
    campaign_manager.start_campaign()
    var mission = campaign_manager.generate_mission()
    
    # Start battle
    state_manager.transition_to("BATTLE")
    assert_eq(state_manager.get_current_state(), "BATTLE", "Should be in battle state")
    
    # Setup battlefield
    var battlefield_ready = campaign_manager.setup_battlefield(mission)
    assert_true(battlefield_ready, "Battlefield should be ready")
    
    # End battle
    campaign_manager.end_battle(true) # true = victory
    assert_eq(state_manager.get_current_state(), "POST_BATTLE", "Should be in post-battle state")

# Save/Load Tests
func test_save_load_flow():
    # Setup initial game state
    state_manager.start_new_game()
    campaign_manager.create_character()
    campaign_manager.start_campaign()
    
    # Save game
    var save_successful = campaign_manager.save_game("test_save")
    assert_true(save_successful, "Should save game successfully")
    
    # Reset state
    state_manager.reset_state()
    campaign_manager.reset()
    
    # Load game
    var load_successful = campaign_manager.load_game("test_save")
    assert_true(load_successful, "Should load game successfully")
    assert_eq(state_manager.get_current_state(), "CAMPAIGN_RUNNING", "Should restore previous game state")

# Event Chain Tests
func test_event_chain():
    state_manager.start_new_game()
    
    var events_received = []
    state_manager.connect("state_changed", func(new_state): events_received.append(new_state))
    
    campaign_manager.create_character()
    campaign_manager.start_campaign()
    campaign_manager.generate_mission()
    state_manager.transition_to("BATTLE")
    
    assert_true("CAMPAIGN_SETUP" in events_received, "Should receive campaign setup event")
    assert_true("CAMPAIGN_RUNNING" in events_received, "Should receive campaign running event")
    assert_true("BATTLE" in events_received, "Should receive battle event")

# Error Recovery Tests
func test_error_recovery():
    state_manager.start_new_game()
    
    # Simulate error in campaign setup
    campaign_manager.force_error = true # Assuming we have a debug flag for testing
    var setup_result = campaign_manager.start_campaign()
    assert_false(setup_result, "Should fail campaign setup")
    
    # Verify error recovery
    assert_eq(state_manager.get_current_state(), "ERROR", "Should enter error state")
    state_manager.recover_from_error()
    assert_eq(state_manager.get_current_state(), "IDLE", "Should recover to idle state")

# Performance Flow Tests
func test_state_transition_performance():
    var start_time = Time.get_ticks_msec()
    
    for i in range(100):
        state_manager.transition_to("IDLE")
        state_manager.transition_to("CAMPAIGN_SETUP")
        state_manager.transition_to("CAMPAIGN_RUNNING")
        state_manager.transition_to("BATTLE")
    
    var end_time = Time.get_ticks_msec()
    var total_time = end_time - start_time
    
    assert_lt(total_time, 1000, "State transitions should complete within 1 second") 