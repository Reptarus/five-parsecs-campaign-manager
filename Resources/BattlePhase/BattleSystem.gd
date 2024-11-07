class_name BattleSystem
extends Node

signal battle_started
signal battle_ended(victory: bool)
signal turn_started(character: Character)
signal turn_ended(character: Character)

var combat_manager: CombatManager
var battlefield_generator: BattlefieldGenerator
var enemy_deployment_manager: EnemyDeploymentManager
var game_state: GameState

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    combat_manager = CombatManager.new()
    battlefield_generator = load("res://Resources/BattlePhase/BattlefieldGenerator.gd").new()
    enemy_deployment_manager = load("res://Resources/GameData/EnemyDeploymentManager.gd").new()

func start_battle(mission: Mission) -> void:
    # Generate battlefield
    var battlefield_data = battlefield_generator.generate_battlefield(mission)
    
    # Deploy forces
    _deploy_forces(mission, battlefield_data)
    
    # Start combat
    combat_manager.start_combat()
    battle_started.emit()

func _deploy_forces(mission: Mission, battlefield_data: Dictionary) -> void:
    # Deploy player forces
    for character in game_state.current_crew.members:
        if character.status == GlobalEnums.CharacterStatus.ACTIVE:
            combat_manager.deploy_character(character, _get_deployment_position())
    
    # Deploy enemy forces
    var _enemy_positions = enemy_deployment_manager.generate_deployment(
        mission.enemy_type,
        battlefield_data
    )
    enemy_deployment_manager.deploy_enemies(mission.enemies, battlefield_data)

func _get_deployment_position() -> Vector2:
    # Implement deployment position logic
    return Vector2.ZERO

func handle_turn(character: Character) -> void:
    turn_started.emit(character)
    
    if character in game_state.current_crew.members:
        # Player turn
        _handle_player_turn(character)
    else:
        # AI turn
        _handle_ai_turn(character)
    
    turn_ended.emit(character)

func _handle_player_turn(character: Character) -> void:
    # Enable player controls for this character
    game_state.ui_manager.enable_character_controls(character)

func _handle_ai_turn(character: Character) -> void:
    # Let AI handle the turn
    combat_manager.handle_ai_turn(character)

func end_battle(victory: bool) -> void:
    combat_manager.end_combat(victory)
    battle_ended.emit(victory)