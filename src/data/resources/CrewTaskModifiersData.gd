@tool
class_name CrewTaskModifiersData
extends Resource

## Crew task modifiers data for world phase activities

@export var name: String = ""
@export var version: String = ""
@export var source: String = ""
@export var description: String = ""
@export var task_types: Dictionary = {}
@export var universal_modifiers: Dictionary = {}
@export var special_rules: Dictionary = {}

func get_task_modifiers(task_type: String) -> Dictionary:
	"""Get modifiers for a specific task type"""
	return task_types.get(task_type, {})

func get_world_type_modifier(world_type: String, task_type: String) -> int:
	"""Get world type modifier for a specific task"""
	var world_modifiers = universal_modifiers.get("world_type_modifiers", {})
	var world_data = world_modifiers.get(world_type, {})
	return world_data.get(task_type, 0)