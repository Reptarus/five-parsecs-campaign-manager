class_name MissionTemplate
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export_group("Mission Details")
@export var type: GameEnums.MissionType
@export var title_templates: Array[String] = []
@export var description_templates: Array[String] = []
@export var objective: GameEnums.MissionObjective
@export var objective_description: String = ""

@export_group("Requirements")
@export var reward_range: Vector2 = Vector2(100, 1000)
@export var difficulty_range: Vector2 = Vector2(1, 5)
@export var required_skills: Array[int] = []
@export var enemy_types: Array[int] = []

@export_group("Chances")
@export_range(0, 1) var deployment_condition_chance: float = 0.3
@export_range(0, 1) var notable_sight_chance: float = 0.2

func validate() -> bool:
    if title_templates.is_empty() or description_templates.is_empty():
        push_error("Mission template must have at least one title and description")
        return false
        
    if reward_range.x >= reward_range.y:
        push_error("Invalid reward range")
        return false
        
    if difficulty_range.x >= difficulty_range.y:
        push_error("Invalid difficulty range")
        return false
        
    return true 