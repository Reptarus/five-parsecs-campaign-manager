@tool
extends Resource

## Base class for all mission-related resources
##
## Provides core functionality and type safety for the mission system.
## All mission-related classes should extend from this.

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

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
var mission_type: int = GameEnums.MissionType.NONE
var description: String = ""
var difficulty: int = GameEnums.DifficultyLevel.NORMAL
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
    if data.has("mission_name"):
        mission_name = data.mission_name
    if data.has("mission_type"):
        mission_type = data.mission_type
    if data.has("description"):
        description = data.description
    if data.has("difficulty"):
        difficulty = data.difficulty
    if data.has("objectives"):
        objectives = data.objectives
    if data.has("rewards"):
        rewards = data.rewards
    if data.has("special_rules"):
        special_rules = data.special_rules
    if data.has("minimum_crew_size"):
        minimum_crew_size = data.minimum_crew_size
    if data.has("required_skills"):
        required_skills = data.required_skills
    if data.has("required_equipment"):
        required_equipment = data.required_equipment

## Complete a specific objective
func complete_objective(index: int) -> void:
    if index >= 0 and index < objectives.size():
        objectives[index].completed = true
        objective_completed.emit(index)
        _check_mission_completion()

## Reset a specific objective
func reset_objective(index: int) -> void:
    if index >= 0 and index < objectives.size():
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
    return (completed as float / objectives.size() as float) * 100.0

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
    var crew_skills: Array = capabilities.get("skills", [])
    for skill in required_skills:
        if not skill in crew_skills:
            result.valid = false
            result.missing.append("missing_skill_%s" % skill)
    
    # Check required equipment
    var crew_equipment: Array = capabilities.get("equipment", [])
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