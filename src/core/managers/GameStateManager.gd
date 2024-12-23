extends Node

# Preload all required resources
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/data/resources/GameState/GameState.gd")
const StoryQuestData = preload("res://src/core/story/StoryQuestData.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const SaveManager = preload("res://src/data/resources/Core/GameState/SaveManager.gd")

signal game_started
signal game_ended
signal game_saved
signal game_loaded
signal state_changed(new_state: GameEnums.GameState)
signal campaign_phase_changed(new_phase: GameEnums.CampaignPhase)
signal battle_phase_changed(new_phase: GameEnums.BattlePhase)
signal campaign_victory_achieved(victory_type: GameEnums.CampaignVictoryType)
signal resource_updated(resource_type: int, amount: int)
signal difficulty_changed(new_difficulty: GameEnums.DifficultyMode)
signal tutorial_state_changed(is_active: bool, tutorial_type: String)

# Game state
var game_state: FiveParsecsGameState
var current_save_slot: int = -1
var is_tutorial: bool = false
var current_state: GameEnums.GameState = GameEnums.GameState.SETUP
var current_campaign_phase: GameEnums.CampaignPhase = GameEnums.CampaignPhase.SETUP
var current_battle_phase: GameEnums.BattlePhase = GameEnums.BattlePhase.SETUP
var difficulty_mode: GameEnums.DifficultyMode = GameEnums.DifficultyMode.NORMAL

# Core managers
var save_manager: SaveManager
var campaign_manager: Node  # Will be set at runtime
var battle_state_machine: Node  # Will be set at runtime
var world_manager: Node  # Will be set at runtime

func _ready() -> void:
    save_manager = SaveManager.new()
    add_child(save_manager)
    _initialize_game_state()
    _connect_signals()

func _initialize_game_state() -> void:
    game_state = FiveParsecsGameState.new()
    game_state.difficulty_mode = difficulty_mode

func _connect_signals() -> void:
    if save_manager:
        save_manager.save_completed.connect(_on_save_completed)
        save_manager.load_completed.connect(_on_load_completed)

# State management
func change_game_state(new_state: GameEnums.GameState) -> void:
    if new_state == current_state:
        return
        
    var old_state = current_state
    current_state = new_state
    _handle_state_transition(old_state, new_state)
    state_changed.emit(new_state)

func change_campaign_phase(new_phase: GameEnums.CampaignPhase) -> void:
    if new_phase == current_campaign_phase:
        return
        
    var old_phase = current_campaign_phase
    current_campaign_phase = new_phase
    _handle_campaign_phase_transition(old_phase, new_phase)
    campaign_phase_changed.emit(new_phase)

func change_battle_phase(new_phase: GameEnums.BattlePhase) -> void:
    if new_phase == current_battle_phase:
        return
        
    var old_phase = current_battle_phase
    current_battle_phase = new_phase
    _handle_battle_phase_transition(old_phase, new_phase)
    battle_phase_changed.emit(new_phase)

# Resource management
func update_resource(resource_type: int, amount: int) -> void:
    if not game_state:
        return
        
    match resource_type:
        GameEnums.ResourceType.CREDITS:
            game_state.credits += amount
        GameEnums.ResourceType.SUPPLIES:
            game_state.supplies += amount
        GameEnums.ResourceType.STORY_POINTS:
            game_state.story_points += amount
    
    resource_updated.emit(resource_type, amount)

# Difficulty management
func set_difficulty(new_difficulty: GameEnums.DifficultyMode) -> void:
    difficulty_mode = new_difficulty
    if game_state:
        game_state.difficulty_mode = new_difficulty
    difficulty_changed.emit(new_difficulty)

# Tutorial management
func start_tutorial(tutorial_type: String = "basic") -> void:
    is_tutorial = true
    if campaign_manager:
        campaign_manager.start_tutorial(tutorial_type)
    tutorial_state_changed.emit(true, tutorial_type)

func end_tutorial() -> void:
    is_tutorial = false
    if campaign_manager:
        campaign_manager.complete_tutorial()
    tutorial_state_changed.emit(false, "")

# Save/Load management
func save_game(slot: int = -1) -> void:
    if slot >= 0:
        current_save_slot = slot
    
    var save_data = {
        "game_state": game_state.serialize() if game_state else {},
        "campaign_state": campaign_manager.serialize() if campaign_manager else {},
        "battle_state": battle_state_machine.serialize() if battle_state_machine else {},
        "world_state": world_manager.serialize() if world_manager else {},
        "current_state": current_state,
        "current_campaign_phase": current_campaign_phase,
        "current_battle_phase": current_battle_phase,
        "difficulty_mode": difficulty_mode,
        "is_tutorial": is_tutorial
    }
    
    save_manager.save_game(save_data, current_save_slot)

func load_game(slot: int) -> void:
    current_save_slot = slot
    save_manager.load_game(slot)

# Signal handlers
func _on_save_completed(success: bool, message: String) -> void:
    if success:
        game_saved.emit()
    else:
        push_error("Save failed: " + message)

func _on_load_completed(success: bool, data: Dictionary) -> void:
    if not success:
        push_error("Load failed")
        return
    
    _apply_loaded_data(data)
    game_loaded.emit()

# Internal state handlers
func _handle_state_transition(old_state: GameEnums.GameState, new_state: GameEnums.GameState) -> void:
    match new_state:
        GameEnums.GameState.SETUP:
            _handle_setup_state()
        GameEnums.GameState.CAMPAIGN:
            _handle_campaign_state()
        GameEnums.GameState.BATTLE:
            _handle_battle_state()
        GameEnums.GameState.GAME_OVER:
            _handle_game_over_state()

func _handle_campaign_phase_transition(old_phase: GameEnums.CampaignPhase, new_phase: GameEnums.CampaignPhase) -> void:
    if campaign_manager:
        campaign_manager.change_phase(new_phase)

func _handle_battle_phase_transition(old_phase: GameEnums.BattlePhase, new_phase: GameEnums.BattlePhase) -> void:
    if battle_state_machine:
        battle_state_machine.change_phase(new_phase)

func _handle_setup_state() -> void:
    current_campaign_phase = GameEnums.CampaignPhase.SETUP
    current_battle_phase = GameEnums.BattlePhase.SETUP
    _initialize_game_state()

func _handle_campaign_state() -> void:
    if campaign_manager:
        campaign_manager.initialize_campaign()

func _handle_battle_state() -> void:
    if battle_state_machine:
        battle_state_machine.initialize_battle()

func _handle_game_over_state() -> void:
    game_ended.emit()

func _apply_loaded_data(data: Dictionary) -> void:
    if data.has("game_state") and game_state:
        game_state.deserialize(data.game_state)
    
    if data.has("campaign_state") and campaign_manager:
        campaign_manager.deserialize(data.campaign_state)
    
    if data.has("battle_state") and battle_state_machine:
        battle_state_machine.deserialize(data.battle_state)
    
    if data.has("world_state") and world_manager:
        world_manager.deserialize(data.world_state)
    
    current_state = data.get("current_state", GameEnums.GameState.SETUP)
    current_campaign_phase = data.get("current_campaign_phase", GameEnums.CampaignPhase.SETUP)
    current_battle_phase = data.get("current_battle_phase", GameEnums.BattlePhase.SETUP)
    difficulty_mode = data.get("difficulty_mode", GameEnums.DifficultyMode.NORMAL)
    is_tutorial = data.get("is_tutorial", false)
