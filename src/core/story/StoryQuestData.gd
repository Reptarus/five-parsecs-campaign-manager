@tool
extends Resource
# class_name StoryQuestData  # Removed to avoid global script class conflict

## Simple story quest/mission data for Five Parsecs
##
## Contains mission parameters and requirements

@export var quest_id: String = ""
@export var quest_name: String = ""
@export var description: String = ""
@export var quest_type: int = 0
@export var difficulty: int = 1
@export var min_crew_size: int = 1
@export var max_crew_size: int = 6
@export var required_equipment: Array[String] = []
@export var rewards: Dictionary = {}
@export var objectives: Array[String] = []
@export var location_requirements: Array[String] = []
@export var available: bool = true
@export var completed: bool = false
@export var failed: bool = false

func _init() -> void:
	quest_id = "quest_" + str(randi())
	quest_name = "New Quest"
	description = "A new mission awaits."
	difficulty = 1
	min_crew_size = 1
	max_crew_size = 6
	rewards = {"credits": 100}
	objectives = ["Complete the mission"]

## Check if quest can be started with given crew size

func can_start_with_crew_size(crew_size: int) -> bool:
	return crew_size >= min_crew_size and crew_size <= max_crew_size

## Check if quest has specific requirement
func has_requirement(requirement: String) -> bool:
	return requirement in required_equipment or requirement in location_requirements

## Get quest difficulty string
func get_difficulty_string() -> String:
	match difficulty:
		1: return "Easy"
		2: return "Normal"
		3: return "Hard"
		4: return "Very Hard"
		5: return "Extreme"
		_: return "Unknown"

## Mark quest as completed
func complete_quest() -> void:
	completed = true
	available = false

## Mark quest as failed

func fail_quest() -> void:
	failed = true
	available = false

## Reset quest status

func reset_quest() -> void:
	completed = false
	failed = false
	available = true

## Serialize quest data

func serialize() -> Dictionary:
	return {
		"quest_id": quest_id,
		"quest_name": quest_name,
		"description": description,
		"quest_type": quest_type,
		"difficulty": difficulty,
		"min_crew_size": min_crew_size,
		"max_crew_size": max_crew_size,
		"required_equipment": required_equipment,
		"rewards": rewards,
		"objectives": objectives,
		"location_requirements": location_requirements,
		"available": available,
		"completed": completed,
		"failed": failed
	}

## Deserialize quest data
func deserialize(data: Dictionary) -> void:
	quest_id = data.get("quest_id", "")
	quest_name = data.get("quest_name", "")
	description = data.get("description", "")
	quest_type = data.get("quest_type", 0)
	difficulty = data.get("difficulty", 1)
	min_crew_size = data.get("min_crew_size", 1)
	max_crew_size = data.get("max_crew_size", 6)
	required_equipment = data.get("required_equipment", [])
	rewards = data.get("rewards", {})
	objectives = data.get("objectives", [])
	location_requirements = data.get("location_requirements", [])
	available = data.get("available", true)
	completed = data.get("completed", false)
	failed = data.get("failed", false)
## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null