@tool
extends Node

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const Character := preload("res://src/core/character/Base/Character.gd")
const FiveParsecsGameState := preload("res://src/core/state/GameState.gd")

signal task_assigned(character: Character, task: int)
signal task_completed(character: Character, task: int, success: bool)
signal task_failed(character: Character, task: int, reason: String)

var game_state: FiveParsecsGameState
var active_tasks: Dictionary = {} # Character: int (task)

func _init(_game_state: FiveParsecsGameState) -> void:
	if not _game_state:
		push_error("GameState is required for CrewTaskManager")
		return
	game_state = _game_state

func assign_task(crew_member: Character, task: int) -> bool:
	if not crew_member:
		push_error("CrewMember is required for task assignment")
		return false
		
	if crew_member.is_busy():
		push_error("CrewMember is already assigned to a task")
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
	task_completed.emit(crew_member, completed_task)
