extends Node

enum CampaignPhase {
    UPKEEP,
    WORLD_STEP,
    TRAVEL,
    BATTLE,
    POST_BATTLE,
    PATRONS
}

signal phase_started(phase: int)
signal phase_completed(phase: int)
signal campaign_completed

var current_phase: CampaignPhase = CampaignPhase.UPKEEP
var game_state: Node  # Will be cast to GameState at runtime
var world_phase_manager: Node  # Will be cast to WorldPhaseManager at runtime
var travel_manager: Node  # Will be cast to TravelManager at runtime
var battle_manager: Node  # Will be cast to BattleManager at runtime
var post_battle_manager: Node  # Will be cast to PostBattleManager at runtime
var patron_manager: Node  # Will be cast to PatronManager at runtime

func _ready() -> void:
    game_state = get_node("/root/GameStateManager")
    if not game_state:
        push_error("GameStateManager instance not found")
        queue_free()
        return
        
    initialize_managers()
    connect_signals()

func initialize_managers() -> void:
    world_phase_manager = Node.new()  # Will be replaced with WorldPhaseManager at runtime
    travel_manager = Node.new()  # Will be replaced with TravelManager at runtime
    battle_manager = Node.new()  # Will be replaced with BattleManager at runtime
    post_battle_manager = Node.new()  # Will be replaced with PostBattleManager at runtime
    patron_manager = Node.new()  # Will be replaced with PatronManager at runtime
    
    add_child(world_phase_manager)
    add_child(travel_manager)
    add_child(battle_manager)
    add_child(post_battle_manager)
    add_child(patron_manager)

func connect_signals() -> void:
    if game_state:
        game_state.connect("state_changed", _on_game_state_changed)
    
    world_phase_manager.connect("world_phase_completed", _on_world_phase_completed)
    travel_manager.connect("travel_completed", _on_travel_completed)
    battle_manager.connect("battle_completed", _on_battle_completed)
    post_battle_manager.connect("post_battle_completed", _on_post_battle_completed)
    patron_manager.connect("patron_interactions_completed", _on_patron_interactions_completed)

func start_campaign() -> void:
    current_phase = CampaignPhase.UPKEEP
    handle_current_phase()

func handle_current_phase() -> void:
    phase_started.emit(current_phase)
    
    match current_phase:
        CampaignPhase.UPKEEP:
            handle_upkeep()
        CampaignPhase.WORLD_STEP:
            handle_world_step()
        CampaignPhase.TRAVEL:
            handle_travel()
        CampaignPhase.BATTLE:
            handle_battle()
        CampaignPhase.POST_BATTLE:
            handle_post_battle()
        CampaignPhase.PATRONS:
            handle_patrons()

func handle_upkeep() -> void:
    var upkeep_cost = game_state.calculate_upkeep()
    if game_state.can_afford(upkeep_cost):
        game_state.spend_credits(upkeep_cost)
        game_state.perform_ship_repairs()
    else:
        handle_failed_upkeep()
    
    advance_phase()

func handle_world_step() -> void:
    world_phase_manager.start_world_phase()

func handle_travel() -> void:
    if game_state.has_selected_destination():
        travel_manager.start_travel()
    else:
        advance_phase()

func handle_battle() -> void:
    if game_state.current_mission:
        battle_manager.start_battle()
    else:
        advance_phase()

func handle_post_battle() -> void:
    post_battle_manager.start_post_battle_sequence()

func handle_patrons() -> void:
    patron_manager.process_patron_interactions()

func advance_phase() -> void:
    var phases = CampaignPhase.values()
    var current_index = phases.find(current_phase)
    if current_index < phases.size() - 1:
        current_phase = phases[current_index + 1]
        phase_completed.emit(current_phase)
        handle_current_phase()
    else:
        campaign_completed.emit()

func handle_failed_upkeep() -> void:
    game_state.apply_failed_upkeep_consequences()
    advance_phase()

func _on_game_state_changed() -> void:
    if game_state.current_state == GlobalEnums.GameState.CAMPAIGN:
        start_campaign()

func _on_world_phase_completed() -> void:
    advance_phase()

func _on_travel_completed() -> void:
    advance_phase()

func _on_battle_completed() -> void:
    advance_phase()

func _on_post_battle_completed() -> void:
    advance_phase()

func _on_patron_interactions_completed() -> void:
    advance_phase()

func get_current_phase() -> int:
    return current_phase