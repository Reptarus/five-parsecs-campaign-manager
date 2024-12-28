class_name BattleTutorialManager
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const UnifiedTerrainSystem = preload("res://src/core/terrain/UnifiedTerrainSystem.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")
const CombatManager = preload("res://src/core/battle/CombatManager.gd")
const BattleTutorialLayout = preload("res://src/core/tutorial/BattleTutorialLayout.gd")

signal tutorial_objective_completed(objective_id: String)
signal tutorial_step_completed(step_id: String)

var current_layout: Dictionary
var current_step: String = "movement_basics"
var combat_manager: CombatManager
var tutorial_overlay: Control

func _ready() -> void:
    combat_manager = get_parent() as CombatManager
    if not combat_manager:
        push_error("BattleTutorialManager must be a child of CombatManager")
        return
        
    _connect_signals()
    load_current_step()

func _connect_signals() -> void:
    if combat_manager:
        combat_manager.unit_moved.connect(_on_unit_moved)
        combat_manager.combat_action_completed.connect(_on_combat_action_completed)
        combat_manager.objective_reached.connect(_on_objective_reached)

func load_current_step() -> void:
    current_layout = BattleTutorialLayout.get_layout(current_step)
    setup_battlefield()
    show_step_guidance()

func setup_battlefield() -> void:
    if not combat_manager:
        return
        
    # Set grid size
    combat_manager.set_grid_size(current_layout.grid_size)
    
    # Place terrain
    for terrain in current_layout.terrain:
        combat_manager.add_terrain(
            terrain.type,
            terrain.position
        )
    
    # Place player units
    combat_manager.set_player_start(current_layout.player_start)
    
    # Place enemies
    for enemy in current_layout.enemies:
        combat_manager.spawn_enemy(
            enemy.type,
            enemy.position
        )
    
    # Set objectives
    for objective in current_layout.objectives:
        combat_manager.add_objective(
            objective.type,
            objective.position
        )

func show_step_guidance() -> void:
    if tutorial_overlay:
        var guidance = get_step_guidance()
        tutorial_overlay.show_guidance(guidance)

func get_step_guidance() -> Dictionary:
    match current_step:
        "movement_basics":
            return {
                "title": "Basic Movement",
                "content": "Click on a unit and move them to the highlighted position.",
                "highlight_position": current_layout.objectives[0].position
            }
        "combat_basics":
            return {
                "title": "Basic Combat",
                "content": "Move within range and attack the enemy unit.",
                "highlight_position": current_layout.enemies[0].position
            }
        "tactical_cover":
            return {
                "title": "Using Cover",
                "content": "Use cover to protect your units while advancing.",
                "highlight_terrain": true
            }
        _:
            return {}

func _on_unit_moved(_unit: Node, end_pos: Vector2) -> void:
    if current_step == "movement_basics":
        var objective_pos = current_layout.objectives[0].position
        if end_pos.distance_to(objective_pos) < 1.0:
            tutorial_objective_completed.emit("reach_position")
            advance_tutorial()

func _on_combat_action_completed(action: Dictionary) -> void:
    if current_step == "combat_basics" and action.type == "attack":
        if action.hit:
            tutorial_objective_completed.emit("successful_attack")
            advance_tutorial()

func _on_objective_reached(objective_id: String) -> void:
    if current_step == "tactical_cover" and objective_id == "control_point":
        tutorial_objective_completed.emit("control_point_secured")
        advance_tutorial()

func advance_tutorial() -> void:
    match current_step:
        "movement_basics":
            current_step = "combat_basics"
        "combat_basics":
            current_step = "tactical_cover"
        "tactical_cover":
            tutorial_step_completed.emit("battle_tutorial")
            return
            
    load_current_step()