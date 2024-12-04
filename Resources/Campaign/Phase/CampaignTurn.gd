extends Node

enum TurnPhase {
    UPKEEP,
    WORLD_STEP,
    BATTLE,
    POST_BATTLE
}

signal turn_started
signal turn_ended
signal phase_changed(phase: int)

var current_phase: TurnPhase = TurnPhase.UPKEEP
var turn_number: int = 1
var campaign_manager: CampaignManager
var world_phase_manager: Node
var battle_manager: Node
var post_battle_manager: Node

func _ready() -> void:
    campaign_manager = get_node("/root/CampaignManager")
    if not campaign_manager:
        push_error("CampaignManager instance not found")
        queue_free()
        return
        
    initialize_managers()
    connect_signals()

func initialize_managers() -> void:
    world_phase_manager = get_node_or_null("WorldPhaseManager")
    battle_manager = get_node_or_null("BattleManager")
    post_battle_manager = get_node_or_null("PostBattleManager")
    
    if not world_phase_manager:
        world_phase_manager = Node.new()
        world_phase_manager.name = "WorldPhaseManager"
        add_child(world_phase_manager)
    
    if not battle_manager:
        battle_manager = Node.new()
        battle_manager.name = "BattleManager"
        add_child(battle_manager)
    
    if not post_battle_manager:
        post_battle_manager = Node.new()
        post_battle_manager.name = "PostBattleManager"
        add_child(post_battle_manager)

func connect_signals() -> void:
    if campaign_manager:
        campaign_manager.campaign_turn_started.connect(_on_campaign_turn_started)
        campaign_manager.campaign_turn_ended.connect(_on_campaign_turn_ended)
    
    if world_phase_manager:
        world_phase_manager.connect("world_phase_completed", _on_world_phase_completed)
    if battle_manager:
        battle_manager.connect("battle_completed", _on_battle_completed)
    if post_battle_manager:
        post_battle_manager.connect("post_battle_completed", _on_post_battle_completed)

func start_turn() -> void:
    turn_started.emit()
    current_phase = TurnPhase.UPKEEP
    campaign_manager.change_phase(current_phase)
    handle_current_phase()

func end_turn() -> void:
    turn_number += 1
    campaign_manager.end_campaign_turn()
    turn_ended.emit()

func handle_current_phase() -> void:
    match current_phase:
        TurnPhase.UPKEEP:
            handle_upkeep()
        TurnPhase.WORLD_STEP:
            handle_world_step()
        TurnPhase.BATTLE:
            handle_battle()
        TurnPhase.POST_BATTLE:
            handle_post_battle()

func handle_upkeep() -> void:
    var game_state = campaign_manager.game_state
    var upkeep_cost = game_state.calculate_upkeep()
    
    if game_state.can_afford(upkeep_cost):
        game_state.spend_credits(upkeep_cost)
        game_state.perform_ship_repairs()
    else:
        handle_failed_upkeep()
    
    advance_phase()

func handle_world_step() -> void:
    world_phase_manager.start_world_phase()

func handle_battle() -> void:
    if campaign_manager.game_state.current_mission:
        battle_manager.start_battle()
    else:
        advance_phase()

func handle_post_battle() -> void:
    post_battle_manager.start_post_battle_sequence()

func advance_phase() -> void:
    var phases = TurnPhase.values()
    var current_index = phases.find(current_phase)
    
    if current_index < phases.size() - 1:
        current_phase = phases[current_index + 1]
        campaign_manager.change_phase(current_phase)
        phase_changed.emit(current_phase)
        handle_current_phase()
    else:
        end_turn()

func handle_failed_upkeep() -> void:
    campaign_manager.game_state.apply_failed_upkeep_consequences()
    advance_phase()

# Signal handlers
func _on_campaign_turn_started(_turn: int) -> void:
    start_turn()

func _on_campaign_turn_ended(_turn: int) -> void:
    # Handle any cleanup needed when campaign turn ends
    pass

func _on_world_phase_completed() -> void:
    advance_phase()

func _on_battle_completed() -> void:
    advance_phase()

func _on_post_battle_completed() -> void:
    advance_phase()

func get_turn_number() -> int:
    return turn_number

func get_current_phase() -> int:
    return current_phase 