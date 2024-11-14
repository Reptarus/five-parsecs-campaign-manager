class_name BattleSystem
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const Character = preload("res://Resources/CrewAndCharacters/Character.gd")
const Mission = preload("res://Resources/GameData/Mission.gd")
const GameState = preload("res://Resources/GameData/GameState.gd")

signal battle_started
signal battle_ended(victory: bool)
signal turn_started(character: Character)
signal turn_ended(character: Character)
signal phase_changed(new_phase: int)  # GlobalEnums.BattlePhase

@export_group("Core Systems")
@export var combat_manager: CombatManager
@export var battlefield_generator: Node  # Will be typed when BattlefieldGenerator is available
@export var enemy_deployment_manager: Node  # Will be typed when EnemyDeploymentManager is available
@export var battle_event_manager: Node  # Will be typed when BattleEventManager is available

var game_state: GameState
var current_phase: int = GlobalEnums.BattlePhase.REACTION_ROLL
var is_transitioning: bool = false

func _init(_game_state: GameState) -> void:
    if not _game_state:
        push_error("Invalid game state provided to BattleSystem")
        return
        
    game_state = _game_state
    _initialize_managers()

func _initialize_managers() -> void:
    if not combat_manager:
        combat_manager = Node.new()  # Replace with actual manager when available
        combat_manager.name = "CombatManager"
    if not battlefield_generator:
        battlefield_generator = Node.new()  # Replace with actual generator when available
        battlefield_generator.name = "BattlefieldGenerator"
    if not enemy_deployment_manager:
        enemy_deployment_manager = Node.new()  # Replace with actual manager when available
        enemy_deployment_manager.name = "EnemyDeploymentManager"
    if not battle_event_manager:
        battle_event_manager = Node.new()  # Replace with actual manager when available
        battle_event_manager.name = "BattleEventManager"

func start_battle(mission: Mission) -> void:
    if not mission:
        push_error("Invalid mission provided to start_battle")
        return

    var battlefield_data = await battlefield_generator.generate_battlefield(mission)
    _deploy_forces(mission, battlefield_data)
    combat_manager.start_combat()
    current_phase = GlobalEnums.BattlePhase.REACTION_ROLL
    phase_changed.emit(current_phase)
    battle_started.emit()

func _deploy_forces(mission: Mission, battlefield_data: Dictionary) -> void:
    for character in game_state.current_crew.get_active_members():
        var position = _get_deployment_position(battlefield_data.player_deployment_zone)
        combat_manager.deploy_character(character, position)
    
    enemy_deployment_manager.deploy_enemies(
        mission.enemies, 
        battlefield_data.enemy_deployment_zone
    )

func _get_deployment_position(deployment_zone: Array) -> Vector2:
    if deployment_zone.is_empty():
        push_error("Empty deployment zone")
        return Vector2.ZERO
    return deployment_zone[randi() % deployment_zone.size()]

func advance_phase() -> void:
    if is_transitioning:
        return
        
    is_transitioning = true
    _cleanup_current_phase()
    
    var phases = GlobalEnums.BattlePhase.values()
    var current_index = phases.find(current_phase)
    current_phase = phases[(current_index + 1) % phases.size()]
    
    phase_changed.emit(current_phase)
    _initialize_new_phase()
    is_transitioning = false

func _cleanup_current_phase() -> void:
    match current_phase:
        GlobalEnums.BattlePhase.REACTION_ROLL:
            combat_manager.cleanup_reactions()
        GlobalEnums.BattlePhase.QUICK_ACTIONS:
            combat_manager.cleanup_quick_actions()
        GlobalEnums.BattlePhase.ENEMY_ACTIONS:
            combat_manager.cleanup_enemy_actions()
        GlobalEnums.BattlePhase.SLOW_ACTIONS:
            combat_manager.cleanup_slow_actions()
        GlobalEnums.BattlePhase.END_PHASE:
            combat_manager.cleanup_round()

func _initialize_new_phase() -> void:
    match current_phase:
        GlobalEnums.BattlePhase.REACTION_ROLL:
            _handle_reaction_phase()
        GlobalEnums.BattlePhase.QUICK_ACTIONS:
            _handle_quick_actions_phase()
        GlobalEnums.BattlePhase.ENEMY_ACTIONS:
            _handle_enemy_actions_phase()
        GlobalEnums.BattlePhase.SLOW_ACTIONS:
            _handle_slow_actions_phase()
        GlobalEnums.BattlePhase.END_PHASE:
            _handle_end_phase()

func _handle_reaction_phase() -> void:
    for character in combat_manager.get_active_characters():
        var roll = character.roll_reaction()
        combat_manager.set_character_initiative(character, roll)
    combat_manager.sort_initiative_order()

func _handle_quick_actions_phase() -> void:
    for character in combat_manager.get_initiative_order():
        if character.can_act():
            turn_started.emit(character)
            await character.perform_quick_actions()
            turn_ended.emit(character)

func _handle_enemy_actions_phase() -> void:
    for enemy in combat_manager.get_enemy_units():
        if enemy.can_act():
            turn_started.emit(enemy)
            await enemy.perform_actions()
            turn_ended.emit(enemy)

func _handle_slow_actions_phase() -> void:
    for character in combat_manager.get_initiative_order():
        if character.can_act():
            turn_started.emit(character)
            await character.perform_slow_actions()
            turn_ended.emit(character)

func _handle_end_phase() -> void:
    combat_manager.cleanup_round()
    if _check_battle_end():
        var victory_type = GlobalEnums.BattleOutcome.VICTORY if _check_victory() else GlobalEnums.BattleOutcome.DEFEAT
        end_battle(victory_type)

func _check_battle_end() -> bool:
    return combat_manager.is_battle_over()

func _check_victory() -> bool:
    return combat_manager.is_player_victory()

func end_battle(victory: GlobalEnums.VictoryConditionType) -> void:
    combat_manager.end_combat(victory)
    battle_ended.emit(victory)

# Combat Helper Functions
func get_valid_move_positions(character: Character) -> Array[Vector2i]:
    return combat_manager.get_valid_move_positions(character)

func get_valid_attack_positions(character: Character) -> Array[Vector2i]:
    return combat_manager.get_valid_attack_positions(character)

func get_character_at_position(position: Vector2i) -> Character:
    return combat_manager.get_character_at_position(position)

func move_character(character: Character, target_position: Vector2i) -> void:
    await combat_manager.move_character(character, target_position)

func attack_character(attacker: Character, target: Character) -> void:
    await combat_manager.attack_character(attacker, target)