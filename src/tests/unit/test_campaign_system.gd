extends "res://addons/gut/test.gd"

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const CampaignSystem = preload("res://src/core/campaign/CampaignSystem.gd")

var game_state: FiveParsecsGameState
var campaign_system: CampaignSystem

func before_each() -> void:
    game_state = FiveParsecsGameState.new()
    campaign_system = CampaignSystem.new(game_state)

func test_campaign_initialization() -> void:
    var config = {
        "name": "Test Campaign",
        "difficulty_level": GameEnums.DifficultyLevel.NORMAL,
        "enable_permadeath": false,
        "use_story_track": true
    }
    
    campaign_system.start_campaign(config)
    assert_eq(game_state.difficulty_level, GameEnums.DifficultyLevel.NORMAL)

func test_difficulty_change() -> void:
    campaign_system.set_difficulty(GameEnums.DifficultyLevel.HARD)
    assert_eq(game_state.difficulty_level, GameEnums.DifficultyLevel.HARD)
    
    campaign_system.set_difficulty(GameEnums.DifficultyLevel.HARDCORE)
    assert_eq(game_state.difficulty_level, GameEnums.DifficultyLevel.HARDCORE)

func test_campaign_serialization() -> void:
    var config = {
        "name": "Test Campaign",
        "difficulty_level": GameEnums.DifficultyLevel.HARD,
        "enable_permadeath": true,
        "use_story_track": false
    }
    
    campaign_system.start_campaign(config)
    var serialized_data = campaign_system.serialize()
    
    assert_eq(serialized_data.difficulty_level, GameEnums.DifficultyLevel.HARD)
    assert_true(serialized_data.has("current_phase"))
    assert_true(serialized_data.has("tutorial_active"))