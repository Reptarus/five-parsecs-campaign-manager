@tool
extends Node
# Use explicit preloads instead of global class names
const Self = preload("res://src/base/combat/objectives/BaseObjectiveSystem.gd")

# Signals
signal objective_added(objective: Dictionary)
signal objective_updated(objective_id: String, status: Dictionary)
signal objective_completed(objective_id: String)
signal objective_failed(objective_id: String)
signal all_objectives_completed()
signal mission_success()
signal mission_failure()

# Objective status constants
enum ObjectiveStatus {
	PENDING,
	IN_PROGRESS,
	COMPLETED,
	FAILED
}

# Objective types
enum ObjectiveType {
	ELIMINATION,
	CAPTURE,
	DEFEND,
	ESCORT,
	RETRIEVE,
	SURVIVE,
	CUSTOM
}

# Objective priority
enum ObjectivePriority {
	PRIMARY,
	SECONDARY,
	BONUS
}

# Objectives storage
var objectives: Dictionary = {}
var completed_objectives: Array = []
var failed_objectives: Array = []

# Mission status
var mission_status: int = ObjectiveStatus.PENDING
var mission_success_condition: String = "all_primary" # all, all_primary, any_primary, custom

# Virtual methods to be implemented by derived classes
func initialize() -> void:
	objectives.clear()
	completed_objectives.clear()
	failed_objectives.clear()
	mission_status = ObjectiveStatus.PENDING

func add_objective(objective_data: Dictionary) -> String:
	# Generate a unique ID if not provided
	if not "id" in objective_data or objective_data.id.is_empty():
		objective_data.id = _generate_objective_id()
	
	# Set default values if not provided
	if not "type" in objective_data:
		objective_data.type = ObjectiveType.CUSTOM
	if not "priority" in objective_data:
		objective_data.priority = ObjectivePriority.PRIMARY
	if not "status" in objective_data:
		objective_data.status = ObjectiveStatus.PENDING
	if not "progress" in objective_data:
		objective_data.progress = 0.0
	if not "target_progress" in objective_data:
		objective_data.target_progress = 1.0
	if not "description" in objective_data:
		objective_data.description = "Objective " + objective_data.id
	if not "hidden" in objective_data:
		objective_data.hidden = false
	if not "time_limit" in objective_data:
		objective_data.time_limit = -1 # No time limit
	if not "location" in objective_data:
		objective_data.location = Vector2.ZERO
	if not "target_units" in objective_data:
		objective_data.target_units = []
	if not "conditions" in objective_data:
		objective_data.conditions = {}
	if not "rewards" in objective_data:
		objective_data.rewards = {}
	
	# Store the objective
	objectives[objective_data.id] = objective_data
	
	# Emit signal
	objective_added.emit(objective_data)
	
	return objective_data.id

func update_objective_progress(objective_id: String, progress: float) -> void:
	if not objective_id in objectives:
		push_warning("Objective ID not found: " + objective_id)
		return
	
	var objective = objectives[objective_id]
	
	# Update progress
	objective.progress = clamp(progress, 0.0, objective.target_progress)
	
	# Check if completed
	if objective.progress >= objective.target_progress and objective.status != ObjectiveStatus.COMPLETED:
		complete_objective(objective_id)
	else:
		# Just update
		if objective.status == ObjectiveStatus.PENDING:
			objective.status = ObjectiveStatus.IN_PROGRESS
		
		objective_updated.emit(objective_id, objective)

func complete_objective(objective_id: String) -> void:
	if not objective_id in objectives:
		push_warning("Objective ID not found: " + objective_id)
		return
	
	var objective = objectives[objective_id]
	
	# Mark as completed
	objective.status = ObjectiveStatus.COMPLETED
	objective.progress = objective.target_progress
	
	# Add to completed list
	if not objective_id in completed_objectives:
		completed_objectives.append(objective_id)
	
	# Emit signal
	objective_completed.emit(objective_id)
	
	# Check if all objectives are completed
	_check_mission_status()

func fail_objective(objective_id: String) -> void:
	if not objective_id in objectives:
		push_warning("Objective ID not found: " + objective_id)
		return
	
	var objective = objectives[objective_id]
	
	# Mark as failed
	objective.status = ObjectiveStatus.FAILED
	
	# Add to failed list
	if not objective_id in failed_objectives:
		failed_objectives.append(objective_id)
	
	# Emit signal
	objective_failed.emit(objective_id)
	
	# Check mission status
	_check_mission_status()

func get_objective(objective_id: String) -> Dictionary:
	if not objective_id in objectives:
		push_warning("Objective ID not found: " + objective_id)
		return {}
	
	return objectives[objective_id]

func get_all_objectives() -> Dictionary:
	return objectives

func get_objectives_by_priority(priority: int) -> Array:
	var result = []
	
	for id in objectives:
		var objective = objectives[id]
		if objective.priority == priority:
			result.append(objective)
	
	return result

func get_objectives_by_type(type: int) -> Array:
	var result = []
	
	for id in objectives:
		var objective = objectives[id]
		if objective.type == type:
			result.append(objective)
	
	return result

func get_objectives_by_status(status: int) -> Array:
	var result = []
	
	for id in objectives:
		var objective = objectives[id]
		if objective.status == status:
			result.append(objective)
	
	return result

func set_mission_success_condition(condition: String) -> void:
	mission_success_condition = condition

func _check_mission_status() -> void:
	# Check if all objectives are completed
	var all_completed = true
	var any_primary_completed = false
	var all_primary_completed = true
	var any_primary_failed = false
	
	for id in objectives:
		var objective = objectives[id]
		
		if objective.status != ObjectiveStatus.COMPLETED:
			all_completed = false
			
			if objective.priority == ObjectivePriority.PRIMARY:
				all_primary_completed = false
				
				if objective.status == ObjectiveStatus.FAILED:
					any_primary_failed = true
		else:
			if objective.priority == ObjectivePriority.PRIMARY:
				any_primary_completed = true
	
	# Check mission success condition
	var mission_succeeded = false
	var mission_failed = false
	
	match mission_success_condition:
		"all":
			mission_succeeded = all_completed
		"all_primary":
			mission_succeeded = all_primary_completed
		"any_primary":
			mission_succeeded = any_primary_completed
		"custom":
			# Custom logic to be implemented by derived classes
			mission_succeeded = _check_custom_mission_success()
	
	# Check for mission failure
	if any_primary_failed:
		mission_failed = true
	
	# Update mission status
	if mission_succeeded:
		mission_status = ObjectiveStatus.COMPLETED
		mission_success.emit()
		all_objectives_completed.emit()
	elif mission_failed:
		mission_status = ObjectiveStatus.FAILED
		mission_failure.emit()

func _check_custom_mission_success() -> bool:
	# To be implemented by derived classes
	return false

func _generate_objective_id() -> String:
	return "obj_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)

# Utility methods
func get_mission_status() -> int:
	return mission_status

func get_mission_progress() -> float:
	var total_weight = 0.0
	var total_progress = 0.0
	
	for id in objectives:
		var objective = objectives[id]
		var weight = 1.0
		
		# Primary objectives have higher weight
		if objective.priority == ObjectivePriority.PRIMARY:
			weight = 3.0
		elif objective.priority == ObjectivePriority.SECONDARY:
			weight = 1.5
		
		total_weight += weight
		total_progress += (objective.progress / objective.target_progress) * weight
	
	if total_weight > 0:
		return total_progress / total_weight
	else:
		return 0.0

func get_objective_description(objective_id: String) -> String:
	if not objective_id in objectives:
		return ""
	
	var objective = objectives[objective_id]
	return objective.description

func get_objective_progress_text(objective_id: String) -> String:
	if not objective_id in objectives:
		return ""
	
	var objective = objectives[objective_id]
	var progress_percent = (objective.progress / objective.target_progress) * 100
	
	return "%d%%" % progress_percent