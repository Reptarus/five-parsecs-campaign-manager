class_name CampaignTurnManager
extends Node 

signal campaign_turn_started(turn: int)
signal campaign_turn_ended(turn: int)
signal event_generated(event: Dictionary)

# Manager instances
var game_state: GameState
var world_manager: Node  # Will be WorldManager
var mission_manager: Node  # Will be MissionManager
var faction_manager: Node  # Will be FactionManager

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    
    # Initialize managers with proper type casting
    var WorldManagerScript = load("res://Resources/GameData/WorldManager.gd")
    var MissionManagerScript = load("res://Resources/GameData/MissionManager.gd")
    var FactionManagerScript = load("res://Resources/GameData/FactionManager.gd")
    
    world_manager = WorldManagerScript.new(game_state) as Node
    mission_manager = MissionManagerScript.new(game_state) as Node
    faction_manager = FactionManagerScript.new(game_state) as Node

func start_campaign_turn() -> void:
    game_state.campaign_turn += 1
    campaign_turn_started.emit(game_state.campaign_turn)
    
    # Process world events
    if world_manager.has_method("process_world_events"):
        world_manager.process_world_events()
    
    # Update missions
    if mission_manager.has_method("update_available_missions"):
        mission_manager.update_available_missions()
    
    # Process faction relationships
    if faction_manager.has_method("process_faction_events"):
        faction_manager.process_faction_events()
    
    # Generate random events
    _generate_campaign_events()

func end_campaign_turn() -> void:
    # Process end of turn effects
    if world_manager.has_method("process_end_of_turn"):
        world_manager.process_end_of_turn()
    if mission_manager.has_method("cleanup_expired_missions"):
        mission_manager.cleanup_expired_missions()
    if faction_manager.has_method("update_faction_standings"):
        faction_manager.update_faction_standings()
    
    campaign_turn_ended.emit(game_state.campaign_turn)

func _generate_campaign_events() -> void:
    if randf() < game_state.difficulty_settings.event_frequency:
        var event = _create_random_event()
        event_generated.emit(event)

func _create_random_event() -> Dictionary:
    # Implementation of event generation logic
    return {} 