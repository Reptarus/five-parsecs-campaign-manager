class_name CrewManager
extends Resource

signal crew_updated
signal task_assigned(character: Character, task: GlobalEnums.CrewTask)
signal task_completed(character: Character, task: GlobalEnums.CrewTask)

const MAX_CREW_SIZE := 6
const MIN_CREW_SIZE := 3

var members: Array[Character] = []
var active_tasks: Dictionary = {} # Character: GlobalEnums.CrewTask

func get_available_members() -> Array[Character]:
    return members.filter(func(member: Character) -> bool: 
        return not active_tasks.has(member))

func add_member(character: Character) -> bool:
    if members.size() >= MAX_CREW_SIZE:
        return false
    members.append(character)
    crew_updated.emit()
    return true

func remove_member(character: Character) -> bool:
    if members.size() <= MIN_CREW_SIZE:
        return false
    var index = members.find(character)
    if index != -1:
        members.remove_at(index)
        if active_tasks.has(character):
            active_tasks.erase(character)
        crew_updated.emit()
        return true
    return false

func assign_task(character: Character, task: GlobalEnums.CrewTask) -> bool:
    if not character in members or active_tasks.has(character):
        return false
    active_tasks[character] = task
    task_assigned.emit(character, task)
    return true

func complete_task(character: Character) -> void:
    if not active_tasks.has(character):
        return
    var completed_task = active_tasks[character]
    active_tasks.erase(character)
    task_completed.emit(character, completed_task)

func get_task_description(task: GlobalEnums.CrewTask) -> String:
    match task:
        GlobalEnums.CrewTask.TRADE: return "Search for profitable trade opportunities"
        GlobalEnums.CrewTask.EXPLORE: return "Scout the local area for opportunities"
        GlobalEnums.CrewTask.TRAIN: return "Improve skills through training"
        GlobalEnums.CrewTask.RECRUIT: return "Search for potential crew members"
        GlobalEnums.CrewTask.FIND_PATRON: return "Look for work opportunities"
        GlobalEnums.CrewTask.REPAIR_KIT: return "Repair and maintain equipment"
        GlobalEnums.CrewTask.DECOY: return "Create a diversion"
        GlobalEnums.CrewTask.REST: return "Recover from injuries or stress"
        _: return "Unknown task"
