
# tests/game/campaign/test_introductory_campaign.gd
extends GutTest

const IntroductoryCampaignManager = preload("res://src/game/campaign/IntroductoryCampaignManager.gd") # Assuming this will be created
const GameState = preload("res://src/core/state/GameState.gd") # For DLC check
const Mission = preload("res://src/core/systems/Mission.gd")

var intro_campaign_manager: IntroductoryCampaignManager

func before_each():
    intro_campaign_manager = IntroductoryCampaignManager.new()
    # Mock GameState for DLC check
    mock_class(GameState)
    GameState.mock_method("is_compendium_dlc_unlocked").returns(true) # Assume DLC is unlocked for testing

func test_initial_campaign_state():
    assert_false(intro_campaign_manager.is_active, "Introductory campaign should not be active initially")
    assert_eq(intro_campaign_manager.current_stage, 0, "Current stage should be 0 initially")

func test_start_introductory_campaign():
    intro_campaign_manager.start_campaign()
    assert_true(intro_campaign_manager.is_active, "Introductory campaign should be active after starting")
    assert_eq(intro_campaign_manager.current_stage, 1, "Current stage should be 1 after starting")
    assert_not_null(intro_campaign_manager.get_current_mission(), "Should have a current mission")

func test_advance_stage():
    intro_campaign_manager.start_campaign()
    var initial_mission = intro_campaign_manager.get_current_mission()
    intro_campaign_manager.advance_stage()
    assert_gt(intro_campaign_manager.current_stage, 1, "Stage should advance")
    assert_not_eq(intro_campaign_manager.get_current_mission(), initial_mission, "Mission should change after advancing stage")

func test_campaign_completion():
    intro_campaign_manager.start_campaign()
    # Simulate advancing through all stages
    for i in range(intro_campaign_manager.total_stages):
        intro_campaign_manager.advance_stage()
    assert_true(intro_campaign_manager.is_completed, "Campaign should be completed after all stages")
    assert_false(intro_campaign_manager.is_active, "Campaign should be inactive after completion")

func test_dlc_gating():
    GameState.mock_method("is_compendium_dlc_unlocked").returns(false)
    var new_manager = IntroductoryCampaignManager.new()
    new_manager.start_campaign()
    assert_false(new_manager.is_active, "Campaign should not start if DLC is locked")

# Add tests for specific mission content per stage, handling player choices, etc.
