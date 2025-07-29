@tool
extends GdUnitGameTest

# Real system imports
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const CampaignManager = preload("res://src/core/managers/CampaignManager.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const StoryQuestData = preload("res://src/game/story/StoryQuestData.gd")

# Real system instances
var _campaign_manager: CampaignManager
var _game_state: GameState
var _tracked_objects: Array[Node] = []

# Test constants
const TEST_SAVE_SLOT := "test_campaign"

func before_test() -> void:
    super.before_test()
    
    # Initialize real game systems
    _initialize_real_systems()

func after_test() -> void:
    # Clean up tracked objects
    for obj in _tracked_objects:
        if is_instance_valid(obj):
            obj.queue_free()
    _tracked_objects.clear()
    
    # Clean up main systems
    if is_instance_valid(_campaign_manager):
        _campaign_manager.queue_free()
        _campaign_manager = null
    if is_instance_valid(_game_state):
        _game_state.queue_free()
        _game_state = null
    
    super.after_test()

func _initialize_real_systems() -> void:
    # Initialize real GameState
    _game_state = GameState.new()
    _game_state.name = "TestGameState"
    add_child(_game_state)
    _tracked_objects.append(_game_state)
    
    # Initialize real CampaignManager
    _campaign_manager = CampaignManager.new()
    _campaign_manager.name = "TestCampaignManager"
    _campaign_manager.game_state = _game_state
    add_child(_campaign_manager)
    _tracked_objects.append(_campaign_manager)
    
    # Allow systems to initialize
    await get_tree().process_frame

func _create_test_mission_config() -> Dictionary:
    return {
        "name": "Test Mission",
        "description": "A test mission for integration testing",
        "mission_type": GlobalEnums.MissionType.PATROL,
        "difficulty": 1,
        "reward_credits": 100,
        "reward_experience": 50
    }

func test_mission_creation() -> void:
    """Test that missions can be created using the real campaign manager."""
    # Given a campaign manager with initialized game state
    assert_that(_campaign_manager).is_not_null()
    assert_that(_game_state).is_not_null()
    
    # When creating a mission
    var mission_config := _create_test_mission_config()
    var mission: StoryQuestData = _campaign_manager.create_mission(GlobalEnums.MissionType.PATROL, mission_config)
    
    # Then the mission should be created successfully
    assert_that(mission).is_not_null()
    assert_that(mission.get_title()).is_equal("Test Mission")
    assert_that(mission.get_description()).is_equal("A test mission for integration testing")

func test_campaign_save_load() -> void:
    """Test that campaign state can be saved and loaded."""
    # Given a campaign with some mission data
    var mission_config := _create_test_mission_config()
    var mission := _campaign_manager.create_mission(GlobalEnums.MissionType.PATROL, mission_config)
    
    # When saving the campaign state
    var save_data: Dictionary = _campaign_manager.save_campaign_state()
    assert_that(save_data).is_not_empty()
    assert_that(save_data).contains_keys(["available_missions", "completed_missions", "story_track"])
    
    # When loading the campaign state
    var load_success: bool = _campaign_manager.load_campaign_state(save_data)
    assert_that(load_success).is_true()

func test_mission_workflow() -> void:
    """Test the complete mission workflow from creation to completion."""
    # Given a mission is created
    var mission_config := _create_test_mission_config()
    var mission := _campaign_manager.create_mission(GlobalEnums.MissionType.PATROL, mission_config)
    
    # When starting the mission
    var start_success: bool = _campaign_manager.start_mission(mission)
    assert_that(start_success).is_true()
    
    # Then the mission should be in active missions
    var active_missions: Array[StoryQuestData] = _campaign_manager.get_active_missions()
    assert_that(active_missions).contains([mission])
    
    # When completing the mission
    _campaign_manager.complete_mission(mission)
    
    # Then the mission should be in completed missions
    var completed_missions: Array[StoryQuestData] = _campaign_manager.get_completed_missions()
    assert_that(completed_missions).contains([mission])
    assert_that(active_missions.size()).is_equal(0)

func test_story_track_integration() -> void:
    """Test that story track system integrates properly with campaign manager."""
    # Given the campaign manager has a story track system
    var story_track_system = _campaign_manager.get_story_track_system()
    assert_that(story_track_system).is_not_null()
    
    # When starting the story track
    _campaign_manager.start_story_track()
    
    # Then the story track should be active
    assert_that(_campaign_manager.is_story_track_active()).is_true()
    
    # When getting story track status
    var status: Dictionary = _campaign_manager.get_story_track_status()
    assert_that(status).is_not_empty()
    assert_that(status).contains_key("active")

func test_campaign_validation() -> void:
    """Test that campaign state validation works with real systems."""
    # Given a campaign manager with some test data
    var mission_config := _create_test_mission_config()
    var mission := _campaign_manager.create_mission(GlobalEnums.MissionType.PATROL, mission_config)
    
    # When validating the campaign state
    var validation_result: Dictionary = _campaign_manager.validate_campaign_state()
    
    # Then the validation should pass
    assert_that(validation_result).contains_keys(["valid", "errors", "warnings"])
    assert_that(validation_result.get("valid", false)).is_true()
    assert_that(validation_result.get("errors", [])).is_empty()

func test_battle_events_integration() -> void:
    """Test that battle events system integrates properly with campaign manager."""
    # Given the campaign manager has battle events initialized
    _campaign_manager.initialize_battle_events()
    
    # When checking for battle events in round 1
    var events: Array = _campaign_manager.check_battle_events(1)
    
    # Then events should be available (array should exist, even if empty)
    assert_that(events).is_not_null()
    
    # When getting environmental hazards
    var hazards: Array = _campaign_manager.get_active_environmental_hazards()
    assert_that(hazards).is_not_null()
    
    # When clearing battle events
    _campaign_manager.clear_battle_events()
    # Should not throw errors
