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
var game_state: Node  # Will be cast to GameState at runtime
var world_phase_manager: Node  # Will be cast to WorldPhaseManager at runtime
var battle_manager: Node  # Will be cast to BattleManager at runtime
var post_battle_manager: Node  # Will be cast to PostBattleManager at runtime

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
    battle_manager = Node.new()  # Will be replaced with BattleManager at runtime
    post_battle_manager = Node.new()  # Will be replaced with PostBattleManager at runtime
    
    add_child(world_phase_manager)
    add_child(battle_manager)
    add_child(post_battle_manager)

func connect_signals() -> void:
    if game_state:
        game_state.connect("state_changed", _on_game_state_changed)
    
    world_phase_manager.connect("world_phase_completed", _on_world_phase_completed)
    battle_manager.connect("battle_completed", _on_battle_completed)
    post_battle_manager.connect("post_battle_completed", _on_post_battle_completed)

func start_turn() -> void:
    turn_started.emit()
    current_phase = TurnPhase.UPKEEP
    handle_current_phase()

func end_turn() -> void:
    turn_number += 1
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
    if game_state.current_mission:
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
        phase_changed.emit(current_phase)
        handle_current_phase()
    else:
        end_turn()

func handle_failed_upkeep() -> void:
    game_state.apply_failed_upkeep_consequences()
    advance_phase()

func _on_game_state_changed() -> void:
    if game_state.current_state == GlobalEnums.GameState.CAMPAIGN:
        start_turn()

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