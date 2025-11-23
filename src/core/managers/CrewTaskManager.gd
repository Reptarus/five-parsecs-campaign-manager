@tool
extends Node

const GlobalEnums := preload("res://src/core/systems/GlobalEnums.gd")
# Character/CharacterDataManager reference removed - file does not exist
const Character = preload("res://src/core/character/Character.gd")
const GameState := preload("res://src/core/state/GameState.gd")
const DataManager := preload("res://src/core/data/DataManager.gd")

signal task_assigned(character: Character, task: int)
signal task_completed(character: Character, task: int, success: bool)
signal task_failed(character: Character, task: int, reason: String)

var game_state: GameState
var active_tasks: Dictionary = {} # Character: int (task)

func _init(_game_state: GameState) -> void:
	if not _game_state:
		push_error("GameState is required for CrewTaskManager")
		return
	game_state = _game_state

func assign_task(crew_member: Character, task: int) -> bool:
	if not crew_member:
		push_error("CrewMember is required for task assignment")
		return false

	# Validate task assignment using Five Parsecs rules
	var validation_result = validate_task_assignment(crew_member, task)
	if not validation_result.valid:
		push_error("Task assignment validation failed: %s" % validation_result.reason)
		task_failed.emit(crew_member, task, validation_result.reason)
		return false

	active_tasks[crew_member] = task
	task_assigned.emit(crew_member, task)
	return true

func complete_task(crew_member: Character) -> void:
	if not active_tasks.has(crew_member):
		push_error("CrewMember has no active task")
		return

	var completed_task = active_tasks[crew_member]
	active_tasks.erase(crew_member)
	task_completed.emit(crew_member, completed_task, true)

## Five Parsecs Validation System
func validate_task_assignment(crew_member: Character, task: int) -> Dictionary:
	"""Validate crew task assignment according to Five Parsecs rules"""
	var result = {"valid": true, "reason": ""}
	
	# Check if crew member is already busy
	if crew_member.is_busy():
		result.valid = false
		result.reason = "Crew member is already assigned to a task"
		return result
	
	# Check wounded/stunned restrictions
	if crew_member.is_wounded and _task_restricted_for_wounded(task):
		result.valid = false
		result.reason = "Wounded crew members cannot perform this task"
		return result
	
	if crew_member.is_stunned and _task_restricted_for_stunned(task):
		result.valid = false
		result.reason = "Stunned crew members cannot perform this task"
		return result
	
	# Check maximum crew tasks per turn
	if get_active_task_count() >= get_max_tasks_per_turn():
		result.valid = false
		result.reason = "Maximum crew tasks per turn already assigned"
		return result
	
	# Check specific task requirements
	var task_validation = _validate_specific_task_requirements(crew_member, task)
	if not task_validation.valid:
		return task_validation
	
	return result

func _task_restricted_for_wounded(task: int) -> bool:
	"""Check if task is restricted for wounded crew members"""
	var restricted_tasks = [
		GlobalEnums.CrewTaskType.TRAIN,
		GlobalEnums.CrewTaskType.EXPLORE
	]
	return task in restricted_tasks

func _task_restricted_for_stunned(task: int) -> bool:
	"""Check if task is restricted for stunned crew members"""
	var restricted_tasks = [
		GlobalEnums.CrewTaskType.TRAIN,
		GlobalEnums.CrewTaskType.FIND_PATRON,
		GlobalEnums.CrewTaskType.TRADE
	]
	return task in restricted_tasks

func _validate_specific_task_requirements(crew_member: Character, task: int) -> Dictionary:
	"""Validate specific requirements for individual tasks"""
	var result = {"valid": true, "reason": ""}
	
	match task:
		GlobalEnums.CrewTaskType.REPAIR_KIT:
			if not _has_repair_equipment():
				result.valid = false
				result.reason = "Repair Kit task requires repair parts and tools"
		GlobalEnums.CrewTaskType.RECRUIT:
			if _get_crew_size() >= 6:
				result.valid = false
				result.reason = "Crew is already at maximum size (6 members)"
		GlobalEnums.CrewTaskType.TRADE:
			if not _has_trade_goods():
				# Note: Trade can still be attempted without goods, just less effective
				pass
	
	return result

func get_active_task_count() -> int:
	"""Get number of currently active crew tasks"""
	return active_tasks.size()

func get_max_tasks_per_turn() -> int:
	"""Get maximum number of crew tasks allowed per turn"""
	# Five Parsecs allows up to 6 crew tasks per turn (one per crew member)
	return min(6, _get_crew_size())

func _get_crew_size() -> int:
	"""Get current crew size"""
	if game_state and game_state.has_method("get_crew_size"):
		return game_state.get_crew_size()
	return 4 # Default crew size

func _has_repair_equipment() -> bool:
	"""Check if crew has repair equipment for Repair Kit task"""
	if game_state and game_state.has_method("has_item"):
		return game_state.has_item("repair_parts") and game_state.has_item("tools")
	return true # Default to available for backwards compatibility

func _has_trade_goods() -> bool:
	"""Check if crew has trade goods for enhanced trading"""
	if game_state and game_state.has_method("has_item"):
		return game_state.has_item("trade_goods") or game_state.has_item("luxury_items")
	return false

## Task Management Utilities
func get_available_tasks_for_crew_member(crew_member: Character) -> Array[int]:
	"""Get list of tasks available to a specific crew member"""
	var available_tasks: Array[int] = []
	
	var all_tasks = [
		GlobalEnums.CrewTaskType.FIND_PATRON,
		GlobalEnums.CrewTaskType.TRAIN,
		GlobalEnums.CrewTaskType.TRADE,
		GlobalEnums.CrewTaskType.RECRUIT,
		GlobalEnums.CrewTaskType.EXPLORE,
		GlobalEnums.CrewTaskType.TRACK,
		GlobalEnums.CrewTaskType.REPAIR_KIT,
		GlobalEnums.CrewTaskType.DECOY
	]
	
	for task in all_tasks:
		var validation = validate_task_assignment(crew_member, task)
		if validation.valid:
			available_tasks.append(task)
	
	return available_tasks

func get_optimal_task_assignments() -> Dictionary:
	"""Generate optimal crew task assignments based on crew skills and conditions"""
	var assignments = {}
	
	if not game_state or not game_state.has_method("get_crew_members"):
		return assignments
	
	var crew_members = game_state.get_crew_members()
	var priority_tasks = [
		GlobalEnums.CrewTaskType.TRAIN,
		GlobalEnums.CrewTaskType.FIND_PATRON,
		GlobalEnums.CrewTaskType.TRADE,
		GlobalEnums.CrewTaskType.EXPLORE,
		GlobalEnums.CrewTaskType.RECRUIT,
		GlobalEnums.CrewTaskType.TRACK,
		GlobalEnums.CrewTaskType.REPAIR_KIT,
		GlobalEnums.CrewTaskType.DECOY
	]
	
	# Assign tasks in priority order
	var task_index = 0
	for crew_member in crew_members:
		if task_index >= priority_tasks.size():
			break
		
		var task = priority_tasks[task_index]
		var validation = validate_task_assignment(crew_member, task)
		
		if validation.valid:
			assignments[crew_member] = task
			task_index += 1
	
	return assignments

func clear_all_tasks() -> void:
	"""Clear all active crew task assignments"""
	active_tasks.clear()

func get_task_summary() -> Dictionary:
	"""Get summary of current task assignments"""
	return {
		"active_tasks": active_tasks.size(),
		"max_tasks": get_max_tasks_per_turn(),
		"assignments": active_tasks.duplicate()
	}
