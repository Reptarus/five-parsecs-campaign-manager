class_name BattlePhaseManager
extends Node

signal battle_setup_complete(battle_data: Dictionary)
signal battle_started
signal battle_ended(result: Dictionary)

var game_state: GameState
var current_mission: Mission
var deployment_manager: DeploymentManager
var enemy_manager: EnemyManager

# Core Rules battle setup steps
enum BattleSetupStep {
    DEPLOYMENT_SELECTION,
    TERRAIN_SETUP,
    CREW_DEPLOYMENT,
    ENEMY_DEPLOYMENT,
    MISSION_BRIEFING,
    READY_CHECK
}

var current_setup_step: BattleSetupStep = BattleSetupStep.DEPLOYMENT_SELECTION

# Add at the top of the file
const DeploymentManager = preload("res://Resources/BattlePhase/DeploymentManager.gd")
const EnemyManager = preload("res://Resources/BattlePhase/EnemyManager.gd")

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    deployment_manager = DeploymentManager.new()
    enemy_manager = EnemyManager.new()

func start_battle_setup(mission: Mission) -> void:
    current_mission = mission
    current_setup_step = BattleSetupStep.DEPLOYMENT_SELECTION
    _process_setup_step()

func advance_setup() -> void:
    current_setup_step = (current_setup_step + 1) % BattleSetupStep.size()
    _process_setup_step()

func _process_setup_step() -> void:
    match current_setup_step:
        BattleSetupStep.DEPLOYMENT_SELECTION:
            _handle_deployment_selection()
        BattleSetupStep.TERRAIN_SETUP:
            _handle_terrain_setup()
        BattleSetupStep.CREW_DEPLOYMENT:
            _handle_crew_deployment()
        BattleSetupStep.ENEMY_DEPLOYMENT:
            _handle_enemy_deployment()
        BattleSetupStep.MISSION_BRIEFING:
            _handle_mission_briefing()
        BattleSetupStep.READY_CHECK:
            _handle_ready_check()

func _handle_deployment_selection() -> void:
    # Core Rules: Set up deployment based on mission type
    var deployment_data = {
        "type": current_mission.deployment.type,
        "zones": deployment_manager.generate_deployment_zones(current_mission.deployment.type),
        "special_rules": current_mission.deployment.special_rules
    }
    battle_setup_complete.emit({"step": "deployment", "data": deployment_data})

func _handle_terrain_setup() -> void:
    # Core Rules: Generate terrain based on mission parameters
    var terrain_data = {
        "features": current_mission.deployment.terrain,
        "layout": deployment_manager.generate_terrain_layout(current_mission.deployment.terrain)
    }
    battle_setup_complete.emit({"step": "terrain", "data": terrain_data})

func _handle_crew_deployment() -> void:
    # Core Rules: Set up crew deployment zones
    var crew_data = {
        "deployment_zone": deployment_manager.get_crew_deployment_zone(),
        "valid_positions": deployment_manager.get_valid_crew_positions()
    }
    battle_setup_complete.emit({"step": "crew", "data": crew_data})

func _handle_enemy_deployment() -> void:
    # Core Rules: Set up enemy forces
    var enemy_data = enemy_manager.generate_enemy_deployment(
        current_mission.enemy_force,
        deployment_manager.get_enemy_deployment_zone()
    )
    battle_setup_complete.emit({"step": "enemies", "data": enemy_data})

func _handle_mission_briefing() -> void:
    # Core Rules: Display mission objectives and special rules
    var briefing_data = {
        "objectives": current_mission.get_objective_text(),
        "special_rules": current_mission.special_rules,
        "victory_conditions": _generate_victory_conditions()
    }
    battle_setup_complete.emit({"step": "briefing", "data": briefing_data})

func _handle_ready_check() -> void:
    # Final verification before battle starts
    var battle_data = {
        "mission": current_mission,
        "deployment": deployment_manager.get_deployment_data(),
        "enemies": enemy_manager.get_enemy_data(),
        "terrain": deployment_manager.get_terrain_data()
    }
    battle_started.emit()
    game_state.transition_to_state(GlobalEnums.GameState.BATTLE)

func _generate_victory_conditions() -> Array:
    var conditions = []
    for objective in current_mission.objectives:
        conditions.append({
            "type": objective,
            "description": current_mission._get_objective_description(objective),
            "required": objective == current_mission.objectives[0]  # First objective is primary
        })
    return conditions 