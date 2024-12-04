# PreBattleLoop.gd
extends Node

signal setup_completed(battle_data: Dictionary)
signal setup_cancelled

const Mission = preload("res://Resources/GameData/Mission.gd")
const BattlefieldGenerator = preload("res://Resources/BattlePhase/BattlefieldGenerator.gd")

var game_state: GameState
var current_mission: Mission
var battlefield_generator: BattlefieldGenerator
var deployment_manager: DeploymentManager
var enemy_manager: EnemyManager

# Core Rules setup steps
enum SetupStep {
    MISSION_BRIEFING,
    CREW_SELECTION,
    EQUIPMENT_LOADOUT,
    DEPLOYMENT_PLANNING,
    BATTLEFIELD_PREVIEW,
    FINAL_CHECK
}

var current_step: SetupStep = SetupStep.MISSION_BRIEFING
var setup_data: Dictionary = {}

func _init(_game_state: GameState, _mission: Mission) -> void:
    game_state = _game_state
    current_mission = _mission
    _initialize_managers()

func _initialize_managers() -> void:
    battlefield_generator = BattlefieldGenerator.new()
    deployment_manager = DeploymentManager.new()
    enemy_manager = EnemyManager.new()

func start_setup() -> void:
    current_step = SetupStep.MISSION_BRIEFING
    setup_data.clear()
    _process_current_step()

func advance_setup() -> void:
    if current_step == SetupStep.FINAL_CHECK:
        _finalize_setup()
    else:
        current_step = SetupStep.values()[current_step + 1]
        _process_current_step()

func cancel_setup() -> void:
    setup_cancelled.emit()

func _process_current_step() -> void:
    match current_step:
        SetupStep.MISSION_BRIEFING:
            _handle_mission_briefing()
        SetupStep.CREW_SELECTION:
            _handle_crew_selection()
        SetupStep.EQUIPMENT_LOADOUT:
            _handle_equipment_loadout()
        SetupStep.DEPLOYMENT_PLANNING:
            _handle_deployment_planning()
        SetupStep.BATTLEFIELD_PREVIEW:
            _handle_battlefield_preview()
        SetupStep.FINAL_CHECK:
            _handle_final_check()

func _handle_mission_briefing() -> void:
    setup_data.mission_info = {
        "type": current_mission.mission_type,
        "objectives": current_mission.objectives,
        "difficulty": current_mission.difficulty,
        "special_rules": current_mission.special_rules
    }

func _handle_crew_selection() -> void:
    var available_crew = game_state.current_crew.get_active_members()
    setup_data.crew = {
        "available": available_crew,
        "selected": [],
        "max_size": current_mission.max_crew_size
    }

func _handle_equipment_loadout() -> void:
    setup_data.equipment = {
        "available": game_state.inventory.get_available_equipment(),
        "assigned": {},
        "restrictions": current_mission.equipment_restrictions
    }

func _handle_deployment_planning() -> void:
    var deployment_data = deployment_manager.generate_deployment_zones(
        current_mission.deployment.type
    )
    setup_data.deployment = deployment_data

func _handle_battlefield_preview() -> void:
    var battlefield_data = battlefield_generator.generate_battlefield(current_mission)
    setup_data.battlefield = battlefield_data

func _handle_final_check() -> void:
    if _validate_setup():
        setup_data.ready = true
    else:
        setup_data.ready = false
        setup_data.validation_errors = _get_validation_errors()

func _validate_setup() -> bool:
    # Check crew selection
    if setup_data.crew.selected.size() < current_mission.min_crew_size:
        return false
    
    # Check equipment assignments
    for character in setup_data.crew.selected:
        if not setup_data.equipment.assigned.has(character.id):
            return false
    
    # Check deployment positions
    if not setup_data.deployment.has("crew"):
        return false
    
    return true

func _get_validation_errors() -> Array:
    var errors = []
    
    if setup_data.crew.selected.size() < current_mission.min_crew_size:
        errors.append("Not enough crew members selected")
    
    for character in setup_data.crew.selected:
        if not setup_data.equipment.assigned.has(character.id):
            errors.append("Equipment not assigned to " + character.name)
    
    if not setup_data.deployment.has("crew"):
        errors.append("Crew deployment positions not set")
    
    return errors

func _finalize_setup() -> void:
    if setup_data.ready:
        setup_completed.emit(setup_data)
    else:
        push_error("Cannot finalize setup: validation failed")
