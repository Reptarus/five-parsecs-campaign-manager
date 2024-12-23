class_name GameCampaignManager
extends Node

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const StoryQuestData := preload("res://src/core/story/StoryQuestData.gd")
const UnifiedStorySystem := preload("res://src/core/story/UnifiedStorySystem.gd")
const FiveParcecsSystem := preload("res://src/core/systems/FiveParcecsSystem.gd")
const FiveParsecsGameState := preload("res://src/data/resources/GameState/GameState.gd")
const CampaignSystem := preload("res://src/data/resources/CampaignManagement/CampaignSystem.gd")
const NewCampaignFlow := preload("res://src/data/resources/CampaignManagement/NewCampaignFlow.gd")

signal campaign_initialized
signal campaign_loaded
signal campaign_saved
signal campaign_ended
signal campaign_setup_started
signal campaign_setup_completed(config: Dictionary)

var game_state: FiveParsecsGameState
var campaign_system: CampaignSystem
var save_manager: SaveManager
var new_campaign_flow: NewCampaignFlow

func _init(_game_state: FiveParsecsGameState) -> void:
    game_state = _game_state
    campaign_system = CampaignSystem.new(game_state)
    save_manager = SaveManager.new()
    new_campaign_flow = NewCampaignFlow.new(game_state)
    _connect_signals()

func _connect_signals() -> void:
    campaign_system.campaign_started.connect(_on_campaign_started)
    campaign_system.campaign_turn_completed.connect(_on_turn_completed)
    campaign_system.campaign_victory_achieved.connect(_on_victory_achieved)
    campaign_system.tutorial_completed.connect(_on_tutorial_completed)
    
    new_campaign_flow.campaign_created.connect(_on_campaign_created)
    new_campaign_flow.campaign_setup_completed.connect(_on_setup_completed)
    new_campaign_flow.tutorial_completed.connect(_on_tutorial_completed)

func start_new_campaign() -> void:
    campaign_setup_started.emit()
    new_campaign_flow.start_campaign_setup()

func initialize_new_campaign(config: Dictionary = {}) -> void:
    campaign_system.start_campaign(config)
    campaign_initialized.emit()

func load_campaign(save_data: Dictionary) -> void:
    if not save_data:
        push_error("Invalid save data provided")
        return
        
    campaign_system.deserialize(save_data.get("campaign_system", {}))
    game_state.deserialize(save_data.get("game_state", {}))
    campaign_loaded.emit()

func save_campaign() -> void:
    var save_data = {
        "campaign_system": campaign_system.serialize(),
        "game_state": game_state.serialize(),
        "version": ProjectSettings.get_setting("application/config/version")
    }
    
    save_manager.save_game(save_data)
    campaign_saved.emit()

func end_campaign() -> void:
    # Clean up campaign resources
    campaign_system.queue_free()
    campaign_ended.emit()

func start_tutorial(tutorial_type: String = "basic") -> void:
    campaign_system.start_tutorial(tutorial_type)

func skip_tutorial() -> void:
    campaign_system.complete_tutorial()

func set_difficulty(difficulty: GameEnums.DifficultyMode) -> void:
    campaign_system.set_difficulty(difficulty)

func process_current_phase() -> void:
    campaign_system.process_current_phase()

func advance_phase() -> void:
    campaign_system.advance_phase()

# Signal handlers
func _on_campaign_created(campaign: Resource) -> void:
    # Handle initial campaign creation
    campaign_setup_completed.emit(campaign.campaign_config)

func _on_setup_completed() -> void:
    # Change to campaign dashboard
    get_tree().change_scene_to_file("res://src/data/resources/CampaignManagement/Scenes/CampaignDashboard.tscn")

func _on_campaign_started() -> void:
    # Update UI and game state for campaign start
    get_tree().change_scene_to_file("res://src/data/resources/CampaignManagement/Scenes/CampaignDashboard.tscn")

func _on_turn_completed() -> void:
    # Handle turn completion
    save_campaign()
    campaign_system.check_victory_conditions()

func _on_victory_achieved(victory_type: GameEnums.CampaignVictoryType) -> void:
    # Handle campaign victory
    get_tree().change_scene_to_file("res://src/data/resources/UI/Screens/VictoryScreen.tscn")

func _on_tutorial_completed(tutorial_type: String) -> void:
    # Handle tutorial completion
    if tutorial_type == "basic":
        get_tree().change_scene_to_file("res://src/data/resources/CampaignManagement/Scenes/CampaignDashboard.tscn") 