@tool
extends Resource

## Base class for all mission-related resources
##
## Provides core functionality and type safety for the mission system.
## All mission-related classes should extend from this.

# GlobalEnums available as autoload singleton

# Type-safe signals
signal mission_state_changed(new_state: int)
signal objective_completed(index: int)
signal mission_completed
signal mission_failed
signal mission_cleaned_up

# Type-safe constants
const MISSION_TIMEOUT: float = 2.0
const STABILIZE_TIME: float = 0.1

# Type-safe properties
var mission_id: String = ""
var mission_name: String = ""
var mission_type: int = GlobalEnums.MissionType.NONE
var description: String = ""
var difficulty: int = GlobalEnums.DifficultyLevel.STANDARD
var objectives: Array[Dictionary] = []
var rewards: Dictionary = {}
var special_rules: Array[Dictionary] = []
var is_completed: bool = false
var is_failed: bool = false
var minimum_crew_size: int = 1
var required_skills: Array[String] = []
var required_equipment: Array[String] = []

# Type-safe virtual methods
func _init() -> void:
	mission_id = str(Time.get_unix_time_from_system())

## Initialize the mission with provided data
func initialize(data: Dictionary) -> void:
	if "mission_name" in data:
		mission_name = data.mission_name
	if "mission_type" in data:
		mission_type = data.mission_type
	if "description" in data:
		description = data.description
	if "difficulty" in data:
		difficulty = data.difficulty
	if "objectives" in data:
		objectives = data.objectives
	if "rewards" in data:
		rewards = data.rewards
	if "special_rules" in data:
		special_rules = data.special_rules
	if "minimum_crew_size" in data:
		minimum_crew_size = data.minimum_crew_size
	if "required_skills" in data:
		required_skills = data.required_skills
	if "required_equipment" in data:
		required_equipment = data.required_equipment

## Complete a specific objective
func complete_objective(index: int) -> void:
	if index >= 0 and index < (safe_call_method(objectives, "size") as int):
		objectives[index].completed = true
		objective_completed.emit(index)
		_check_mission_completion()

## Reset a specific objective
func reset_objective(index: int) -> void:
	if index >= 0 and index < (safe_call_method(objectives, "size") as int):
		objectives[index].completed = false
		_check_mission_completion()

## Complete the mission
func complete_mission() -> void:
	is_completed = true
	is_failed = false
	mission_completed.emit()

## Fail the mission
func fail_mission() -> void:
	is_failed = true
	is_completed = false
	mission_failed.emit()

## Clean up mission state
func cleanup() -> void:
	is_completed = false
	is_failed = false
	for objective in objectives:
		objective.completed = false
	mission_cleaned_up.emit()

## Calculate mission completion percentage
func get_completion_percentage() -> float:
	if objectives.is_empty():
		return 0.0
	var completed := objectives.filter(func(obj): return obj.completed).size()

	return (completed as float / (safe_call_method(objectives, "size") as int) as float) * 100.0

## Check if all required objectives are completed
func _check_mission_completion() -> void:
	var primary_objectives := objectives.filter(func(obj): return obj.is_primary)
	if primary_objectives.is_empty():
		return

	var all_primary_completed := primary_objectives.all(func(obj): return obj.completed)
	if all_primary_completed:
		complete_mission()

## Validate mission requirements against provided capabilities
func validate_requirements(capabilities: Dictionary) -> Dictionary:
	var result := {
		"valid": true,
		"missing": []
	}

	# Check crew size
	if capabilities.has("crew_size") and capabilities.crew_size < minimum_crew_size:
		result.valid = false
		result.missing.append("insufficient_crew")

	# Check required skills

	var crew_skills: Array = capabilities.get("skills", []) if capabilities and capabilities.has("skills") else []
	for skill in required_skills:
		if not skill in crew_skills:
			result.valid = false
			result.missing.append("missing_skill_%s" % skill)

	# Check required equipment

	var crew_equipment: Array = capabilities.get("equipment", []) if capabilities and capabilities.has("equipment") else []
	for equipment in required_equipment:
		if not equipment in crew_equipment:
			result.valid = false
			result.missing.append("missing_equipment_%s" % equipment)

	return result

## Calculate final rewards based on completion
func calculate_final_rewards() -> Dictionary:
	if not is_completed:
		return {}

	var final_rewards := rewards.duplicate()
	return final_rewards

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