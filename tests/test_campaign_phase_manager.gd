extends "res://addons/gut/test.gd"

const CampaignPhaseManager = preload("res://src/core/systems/CampaignPhaseManager.gd")
const Campaign = preload("res://src/core/systems/Campaign.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var manager: Node
var campaign: Node

func before_each() -> void:
    manager = CampaignPhaseManager.new()
    campaign = Campaign.new()
    
    # Setup test campaign
    campaign.campaign_type = GameEnums.DifficultyLevel.NORMAL
    campaign.total_resources = 0
    campaign.reputation = 0
    campaign.completed_missions = []
    
    manager.setup(campaign)

func after_each() -> void:
    manager.free()
    campaign.free()

func test_initial_phase() -> void:
    # Test that the campaign starts in EARLY_GAME phase
    assert_has(manager.current_phase, "type", "Current phase should have a type")
    assert_eq(manager.current_phase["type"], "EARLY_GAME", "Initial phase should be EARLY_GAME")

func test_phase_transition_requirements() -> void:
    # Test that phase transition is blocked by minimum requirements
    manager.check_phase_transition()
    assert_eq(manager.current_phase["type"], "EARLY_GAME", "Should not transition without meeting requirements")
    
    # Test transition with minimum missions but insufficient resources/reputation
    campaign.completed_missions = []
    for i in range(CampaignPhaseManager.MIN_PHASE_DURATION):
        campaign.completed_missions.append({})
    manager.check_phase_transition()
    assert_eq(manager.current_phase["type"], "EARLY_GAME", "Should not transition without sufficient resources/reputation")
    
    # Test transition with all requirements met
    campaign.total_resources = CampaignPhaseManager.RESOURCE_THRESHOLDS["MID_GAME"]
    campaign.reputation = CampaignPhaseManager.REPUTATION_THRESHOLDS["MID_GAME"]
    manager.check_phase_transition()
    assert_eq(manager.current_phase["type"], "MID_GAME", "Should transition to MID_GAME when requirements are met")

func test_phase_event_generation() -> void:
    var event = manager.generate_phase_event()
    
    if not event.is_empty():
        assert_has(event, "type", "Event should have a type")
        assert_has(event, "name", "Event should have a name")
        assert_has(event, "event_level", "Event should have an event level")
        assert_has(event, "requirements", "Event should have requirements")

func test_phase_modifiers() -> void:
    var modifiers = manager.get_current_modifiers()
    
    assert_has(modifiers, "resource_multiplier", "Should have resource multiplier")
    assert_has(modifiers, "encounter_difficulty", "Should have encounter difficulty")
    assert_has(modifiers, "available_mission_types", "Should have available mission types")
    
    assert_true(modifiers["resource_multiplier"] > 0, "Resource multiplier should be positive")
    assert_true(modifiers["encounter_difficulty"] > 0, "Encounter difficulty should be positive")
    assert_true(modifiers["available_mission_types"].size() > 0, "Should have at least one available mission type")

func test_late_game_transition() -> void:
    # Setup campaign for late game transition
    campaign.completed_missions = []
    for i in range(CampaignPhaseManager.MIN_PHASE_DURATION * 2):
        campaign.completed_missions.append({})
    campaign.total_resources = CampaignPhaseManager.RESOURCE_THRESHOLDS["MID_GAME"]
    campaign.reputation = CampaignPhaseManager.REPUTATION_THRESHOLDS["MID_GAME"]
    
    # Transition to mid game
    manager.check_phase_transition()
    assert_eq(manager.current_phase["type"], "MID_GAME", "Should be in MID_GAME phase")
    
    # Setup for late game
    campaign.total_resources = CampaignPhaseManager.RESOURCE_THRESHOLDS["LATE_GAME"]
    campaign.reputation = CampaignPhaseManager.REPUTATION_THRESHOLDS["LATE_GAME"]
    
    # Transition to late game
    manager.check_phase_transition()
    assert_eq(manager.current_phase["type"], "LATE_GAME", "Should transition to LATE_GAME when requirements are met")

func test_event_requirements_validation() -> void:
    # Test with no requirements met
    var event = {
        "type": "TEST_EVENT",
        "name": "Test Event",
        "requirements": ["active_crew", "minimum_reputation"]
    }
    
    assert_false(manager._validate_event_requirements(event), "Should fail with no requirements met")
    
    # Test with partial requirements
    campaign.reputation = 10 # Above minimum_reputation requirement
    assert_false(manager._validate_event_requirements(event), "Should fail with only some requirements met")
    
    # Test with all requirements met
    campaign.add_crew_member({"name": "Test Crew", "skills": []})
    assert_true(manager._validate_event_requirements(event), "Should pass with all requirements met")

func test_special_features() -> void:
    var features = manager.get_special_features()
    assert_not_null(features, "Special features should not be null")
    assert_true(features is Array, "Special features should be an array")
    
    # Early game should have specific features
    var early_features = ["starter_equipment", "basic_missions", "recruitment_opportunities"]
    for feature in early_features:
        assert_true(features.has(feature), "Early game should have feature: " + feature)