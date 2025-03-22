# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Node

const Self = preload("res://src/game/tutorial/BattleTutorialManager.gd")

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const UnifiedTerrainSystem = preload("res://src/core/terrain/UnifiedTerrainSystem.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")
const BaseCombatManager = preload("res://src/base/combat/BaseCombatManager.gd")
# Load the BattleTutorialLayout script directly rather than using a global class name
const BattleTutorialLayoutScript = preload("res://src/game/tutorial/BattleTutorialLayout.gd")

signal tutorial_objective_completed(objective_id: String)
signal tutorial_step_completed(step_id: String)

var current_layout: Dictionary
var current_step: String = "movement_basics"
var combat_manager: BaseCombatManager
var tutorial_overlay: Control

func _ready() -> void:
    combat_manager = get_parent() as BaseCombatManager
    if not combat_manager:
        push_error("BattleTutorialManager must be a child of BaseCombatManager")
        return
        
    _connect_signals()
    load_current_step()

func _connect_signals() -> void:
    if combat_manager:
        combat_manager.unit_moved.connect(_on_unit_moved)
        combat_manager.combat_action_completed.connect(_on_combat_action_completed)
        combat_manager.objective_reached.connect(_on_objective_reached)

func load_current_step() -> void:
    # Get the tutorial layout as a Dictionary directly
    current_layout = BattleTutorialLayoutScript.get_layout(current_step)
    setup_battlefield()
    show_step_guidance()

# Static helper to get a layout without creating instances
func get_battle_tutorial_layout(layout_id: String) -> Dictionary:
    # Get the tutorial layout as a Dictionary
    return BattleTutorialLayoutScript.get_layout(layout_id)

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

# Signal handlers
func _on_unit_moved(_unit_id: String, _from: Vector2, _to: Vector2) -> void:
    pass # To be implemented

func _on_combat_action_completed(_action_type: int, _unit_id: String, _target_id: String) -> void:
    pass # To be implemented

func _on_objective_reached(_objective_id: String, _unit_id: String) -> void:
    pass # To be implemented