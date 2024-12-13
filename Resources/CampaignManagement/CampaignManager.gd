class_name GameCampaignManager
extends Node

const GlobalEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")

enum CampaignPhase {
    SETUP,
    WORLD,
    BATTLE,
    POST_BATTLE
}

enum SkillType {
    COMBAT,
    TECHNICAL,
    SOCIAL,
    SURVIVAL
}

enum VictoryType {
    WEALTH,
    REPUTATION,
    POWER,
    DISCOVERY
}

signal phase_changed(new_phase: CampaignPhase)
signal turn_completed
signal campaign_victory_achieved(victory_type: VictoryType)

var game_state: GameState
var current_phase: CampaignPhase = CampaignPhase.SETUP
var use_expanded_missions: bool = false
var story_track: StoryTrack
var save_manager: SaveManager
var save_load_ui: Control

# Add new variables for deferred loading
var _save_load_ui_scene: PackedScene
var _is_initialized: bool = false

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    story_track = StoryTrack.new()
    save_manager = SaveManager.new()
    # Defer scene loading
    _save_load_ui_scene = load("res://Resources/Utilities/SaveLoadUI.tscn")
    
    # Remove immediate instantiation
    save_load_ui = null

func initialize() -> void:
    if _is_initialized:
        return
        
    if _save_load_ui_scene:
        save_load_ui = _save_load_ui_scene.instantiate()
        save_load_ui.hide()
        add_child(save_load_ui)
    else:
        push_error("Failed to load SaveLoadUI scene")
    
    _is_initialized = true

func start_new_turn(main_scene: Node) -> void:
    # Add validation
    if not is_instance_valid(main_scene):
        push_error("Invalid main scene provided")
        return
        
    game_state.current_turn += 1
    game_state.reset_turn_specific_data()
    
    var turn_summary = create_campaign_turn_summary()
    game_state.logbook.add_entry(turn_summary)
    
    # Add validation before showing UI
    if _is_initialized and is_instance_valid(save_load_ui):
        show_save_load_ui()
    else:
        push_warning("SaveLoadUI not initialized, skipping autosave")
    
    if game_state.is_tutorial_active:
        start_tutorial_phase(main_scene)
    else:
        start_world_phase(main_scene)

func start_tutorial_phase(main_scene: Node) -> void:
    var tutorial_phase_scene = load("res://Scenes/campaign/TutorialPhase.tscn").instantiate()
    tutorial_phase_scene.initialize(game_state, story_track)
    main_scene.add_child(tutorial_phase_scene)

func start_world_phase(main_scene: Node) -> void:
    var world_phase_scene = load("res://Scenes/campaign/WorldPhase.tscn").instantiate()
    world_phase_scene.initialize(game_state)
    main_scene.add_child(world_phase_scene)

func create_campaign_turn_summary() -> String:
    return "Turn %d: %s" % [game_state.current_turn, game_state.current_location.name]

func show_save_load_ui() -> void:
    if not is_instance_valid(save_load_ui):
        push_error("SaveLoadUI not initialized")
        return
    save_load_ui.show()
