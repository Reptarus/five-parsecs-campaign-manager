@tool
extends Resource
class_name MissionObjective

## Mission Objective for Five Parsecs from Home
## Represents a single objective within a mission

# GlobalEnums available as autoload singleton

@export var objective_type: int = GlobalEnums.MissionObjective.DEFENSE
@export var description: String = ""
@export var is_optional: bool = false
@export var is_completed: bool = false
@export var target_value: int = 0
@export var current_value: int = 0
@export var rewards: Dictionary = {}

signal objective_completed(objective: MissionObjective)
signal objective_progress_updated(objective: MissionObjective, progress: float)

func _init() -> void:
	_initialize_default_values()

func _initialize_default_values() -> void:
	rewards = {}

func complete_objective() -> void:
	is_completed = true
	objective_completed.emit(self)

func update_progress(_value: int) -> void:
	current_value = _value
	var progress = get_progress_percentage()
	objective_progress_updated.emit(self, progress)

	if current_value >= target_value and not is_completed:
		complete_objective()

func get_progress_percentage() -> float:
	if target_value <= 0:
		return 100.0 if is_completed else 0.0
	return (float(current_value) / float(target_value)) * 100.0

func serialize() -> Dictionary:
	return {
		"objective_type": objective_type,
		"description": description,
		"is_optional": is_optional,
		"is_completed": is_completed,
		"target_value": target_value,
		"current_value": current_value,
		"rewards": rewards
	}

func deserialize(data: Dictionary) -> void:
	objective_type = data.get("objective_type", GlobalEnums.MissionObjective.DEFENSE)
	description = data.get("description", "")
	is_optional = data.get("is_optional", false)
	is_completed = data.get("is_completed", false)
	target_value = data.get("target_value", 0)
	current_value = data.get("current_value", 0)
	rewards = data.get("rewards", {})
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