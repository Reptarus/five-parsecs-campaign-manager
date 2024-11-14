class_name CrewTaskManager
extends Node

signal task_assigned(crew_member: CrewMember, task: GlobalEnums.CrewTask)
signal task_completed(crew_member: CrewMember, task: GlobalEnums.CrewTask)

var game_state: GameState
var active_tasks: Dictionary = {}  # CrewMember: GlobalEnums.CrewTask

func _init(_game_state: GameState) -> void:
    if not _game_state:
        push_error("GameState is required for CrewTaskManager")
        return
    game_state = _game_state

func assign_task(crew_member: CrewMember, task: GlobalEnums.CrewTask) -> bool:
    if not crew_member:
        push_error("CrewMember is required for task assignment")
        return false
        
    if crew_member.is_busy():
        push_error("CrewMember is already assigned to a task")
        return false
        
    active_tasks[crew_member] = task
    task_assigned.emit(crew_member, task)
    return true

func complete_task(crew_member: CrewMember) -> void:
    if not active_tasks.has(crew_member):
        push_error("CrewMember has no active task")
        return
        
    var completed_task = active_tasks[crew_member]
    active_tasks.erase(crew_member)
    task_completed.emit(crew_member, completed_task)