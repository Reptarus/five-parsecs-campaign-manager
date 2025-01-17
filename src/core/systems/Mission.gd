@tool
class_name Mission
extends Resource

## Enums
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

## Mission Properties
@export var mission_id: String
@export var mission_type: int = GameEnums.MissionType.NONE
@export var mission_name: String
@export var description: String
@export var difficulty: int = 0
@export var objectives: Array[Dictionary] = []
@export var rewards: Dictionary
@export var special_rules: Array[String] = []

## Mission State
@export var is_completed: bool = false
@export var is_failed: bool = false
@export var current_phase: String = "preparation"
@export var completion_percentage: float = 0.0

## Mission Points
@export var deployment_points: Array[Vector2] = []
@export var objective_points: Array[Vector2] = []
@export var extraction_points: Array[Vector2] = []

## Mission Requirements
@export var required_skills: Array[String] = []
@export var required_equipment: Array[String] = []
@export var minimum_crew_size: int = 1

## Mission Modifiers
@export var resource_multiplier: float = 1.0
@export var difficulty_multiplier: float = 1.0
@export var reputation_multiplier: float = 1.0

## Signals
signal objective_completed(objective: Dictionary)
signal mission_completed
signal mission_failed
signal phase_changed(new_phase: String)
signal progress_updated(percentage: float)

func _init() -> void:
	mission_id = _generate_mission_id()

## Generate a unique mission ID
func _generate_mission_id() -> String:
	return str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)

## Validate mission requirements against crew capabilities
func validate_requirements(crew_capabilities: Dictionary) -> Dictionary:
	var validation := {"valid": true, "missing": []}
	
	# Check required skills
	for skill in required_skills:
		if not crew_capabilities.get("skills", []).has(skill):
			validation["valid"] = false
			validation["missing"].append("Skill: " + skill)
	
	# Check required equipment
	for equipment in required_equipment:
		if not crew_capabilities.get("equipment", []).has(equipment):
			validation["valid"] = false
			validation["missing"].append("Equipment: " + equipment)
	
	# Check crew size
	if crew_capabilities.get("crew_size", 0) < minimum_crew_size:
		validation["valid"] = false
		validation["missing"].append("Minimum Crew Size: " + str(minimum_crew_size))
	
	return validation

## Complete an objective
func complete_objective(objective_index: int) -> void:
	if objective_index >= 0 and objective_index < objectives.size():
		objectives[objective_index]["completed"] = true
		objective_completed.emit(objectives[objective_index])
		_update_completion_percentage()
		_check_mission_completion()

## Update mission progress
func _update_completion_percentage() -> void:
	var completed := 0
	for objective in objectives:
		if objective["completed"]:
			completed += 1
	
	completion_percentage = float(completed) / max(1, objectives.size()) * 100.0
	progress_updated.emit(completion_percentage)

## Check if mission is complete
func _check_mission_completion() -> void:
	var all_completed := true
	var primary_completed := false
	
	for objective in objectives:
		if objective["is_primary"]:
			primary_completed = objective["completed"]
		if not objective["completed"]:
			all_completed = false
	
	if primary_completed:
		is_completed = true
		mission_completed.emit()

## Fail the mission
func fail_mission() -> void:
	is_failed = true
	mission_failed.emit()

## Change mission phase
func change_phase(new_phase: String) -> void:
	current_phase = new_phase
	phase_changed.emit(new_phase)

## Get mission summary
func get_summary() -> Dictionary:
	return {
		"id": mission_id,
		"name": mission_name,
		"type": mission_type,
		"difficulty": difficulty,
		"completion": completion_percentage,
		"status": _get_status(),
		"objectives": objectives,
		"rewards": rewards
	}

## Get mission status
func _get_status() -> String:
	if is_completed:
		return "completed"
	elif is_failed:
		return "failed"
	else:
		return current_phase

## Calculate final rewards based on completion
func calculate_final_rewards() -> Dictionary:
	if not is_completed:
		return {}
	
	var final_rewards := rewards.duplicate(true)
	
	# Apply modifiers
	if final_rewards.has("credits"):
		final_rewards["credits"] = roundi(final_rewards["credits"] * resource_multiplier)
	
	if final_rewards.has("reputation"):
		final_rewards["reputation"] = roundi(final_rewards["reputation"] * reputation_multiplier)
	
	# Add bonus for completing all objectives
	var all_completed := true
	for objective in objectives:
		if not objective["completed"]:
			all_completed = false
			break
	
	if all_completed:
		final_rewards["bonus_credits"] = roundi(final_rewards.get("credits", 0) * 0.2)
		final_rewards["bonus_reputation"] = 1
	
	return final_rewards

## Add a special rule
func add_special_rule(rule: String) -> void:
	if not special_rules.has(rule):
		special_rules.append(rule)

## Check if mission has a specific special rule
func has_special_rule(rule: String) -> bool:
	return special_rules.has(rule)

## Get active objectives
func get_active_objectives() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for objective in objectives:
		if not objective["completed"]:
			active.append(objective)
	return active

## Get completed objectives
func get_completed_objectives() -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	for objective in objectives:
		if objective["completed"]:
			completed.append(objective)
	return completed
