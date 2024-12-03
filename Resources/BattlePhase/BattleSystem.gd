class_name BattleSystem
extends Node

signal battle_started(mission: Mission)
signal battle_ended(result: Dictionary)
signal phase_changed(new_phase: int)
signal turn_started(character: Character)
signal turn_ended(character: Character)
signal slow_actions_started
signal quick_actions_started

var game_state: GameState
var current_mission: Mission
var current_phase: int = GlobalEnums.BattlePhase.SETUP
var reaction_results: Dictionary = {}
var current_round: int = 1

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func initialize(mission: Mission) -> void:
    current_mission = mission
    current_phase = GlobalEnums.BattlePhase.SETUP
    current_round = 1
    reaction_results.clear()
    battle_started.emit(mission)

func start_battle() -> void:
    if not current_mission:
        push_error("No mission set for battle")
        return
    
    _setup_battle()
    _start_round()

func end_battle(result: Dictionary) -> void:
    battle_ended.emit(result)
    cleanup()

func cleanup() -> void:
    current_mission = null
    current_phase = GlobalEnums.BattlePhase.SETUP
    current_round = 1
    reaction_results.clear()

func start_round() -> void:
    current_round += 1
    _reset_reactions()
    start_quick_actions()

func end_round() -> void:
    if _check_battle_end():
        return
    
    _cleanup_round()
    start_round()

func handle_player_turn(character: Character) -> void:
    if not character or not character.can_act():
        return
    
    turn_started.emit(character)
    await character.turn_completed
    turn_ended.emit(character)

func handle_enemy_turn(enemy: Character) -> void:
    if not enemy or not enemy.can_act():
        return
    
    turn_started.emit(enemy)
    await get_tree().create_timer(0.5).timeout  # Small delay for visual feedback
    turn_ended.emit(enemy)

func start_quick_actions() -> void:
    quick_actions_started.emit()
    var quick_actors = _get_quick_actors()
    for actor in quick_actors:
        if not reaction_results[actor.id].has_acted:
            if actor in game_state.get_active_crew():
                await handle_player_turn(actor)
            else:
                await handle_enemy_turn(actor)
    
    start_slow_actions()

func start_slow_actions() -> void:
    slow_actions_started.emit()
    var slow_actors = _get_slow_actors()
    for actor in slow_actors:
        if not reaction_results[actor.id].has_acted:
            if actor in game_state.get_active_crew():
                await handle_player_turn(actor)
            else:
                await handle_enemy_turn(actor)
    
    end_round()

func _get_quick_actors() -> Array[Dictionary]:
    var quick_actors: Array[Dictionary] = []
    for id in reaction_results.keys():
        if reaction_results[id].is_quick and not reaction_results[id].has_acted:
            quick_actors.append(reaction_results[id])
    return quick_actors

func _get_slow_actors() -> Array[Dictionary]:
    var slow_actors: Array[Dictionary] = []
    for id in reaction_results.keys():
        if not reaction_results[id].is_quick and not reaction_results[id].has_acted:
            slow_actors.append(reaction_results[id])
    return slow_actors

func _setup_battle() -> void:
    _reset_battle_state()
    _initialize_reactions()
    change_phase(GlobalEnums.BattlePhase.DEPLOYMENT)

func _reset_battle_state() -> void:
    current_round = 1
    reaction_results.clear()

func _initialize_reactions() -> void:
    var all_characters = game_state.get_all_characters()
    for character in all_characters:
        reaction_results[character.id] = {
            "character": character,
            "is_quick": character.has_quick_reaction(),
            "has_acted": false
        }

func _reset_reactions() -> void:
    for result in reaction_results.values():
        result.has_acted = false

func _cleanup_round() -> void:
    for character in game_state.get_all_characters():
        character.reset_round_state()

func _check_battle_end() -> bool:
    if current_round > current_mission.max_rounds:
        end_battle({"outcome": "TIMEOUT"})
        return true
    
    if game_state.get_active_enemies().is_empty():
        end_battle({"outcome": "VICTORY"})
        return true
    
    if game_state.get_active_crew().is_empty():
        end_battle({"outcome": "DEFEAT"})
        return true
    
    return false

func _start_round() -> void:
    change_phase(GlobalEnums.BattlePhase.BATTLE)
    start_quick_actions()

func change_phase(new_phase: int) -> void:
    current_phase = new_phase
    phase_changed.emit(new_phase)