class_name CampaignManager
extends Node

signal campaign_turn_started(turn: int)
signal campaign_turn_ended(turn: int)
signal event_generated(event: Dictionary)

var game_state: GameState
var world_manager: WorldManager
var mission_manager: MissionManager
var faction_manager: FactionManager

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    world_manager = WorldManager.new(game_state)
    mission_manager = MissionManager.new(game_state)
    faction_manager = FactionManager.new(game_state)

func start_campaign_turn() -> void:
    game_state.campaign_turn += 1
    campaign_turn_started.emit(game_state.campaign_turn)
    
    # Process world events
    world_manager.process_world_events()
    
    # Update missions
    mission_manager.update_available_missions()
    
    # Process faction relationships
    faction_manager.process_faction_events()
    
    # Generate random events
    _generate_campaign_events()

func end_campaign_turn() -> void:
    # Process end of turn effects
    world_manager.process_end_of_turn()
    mission_manager.cleanup_expired_missions()
    faction_manager.update_faction_standings()
    
    campaign_turn_ended.emit(game_state.campaign_turn)

func _generate_campaign_events() -> void:
    if randf() < game_state.difficulty_settings.event_frequency:
        var event = _create_random_event()
        event_generated.emit(event)

func _create_random_event() -> Dictionary:
    # Implementation of event generation logic
    return {} 