class_name CrewManager
extends Resource

signal crew_updated
signal task_assigned(character: Node, task: int)
signal task_completed(character: Node, task: int)

const MAX_CREW_SIZE := 6
const MIN_CREW_SIZE := 3

# Enum values for CrewTask
enum CrewTask {
    TRADE,
    EXPLORE,
    TRAIN,
    RECRUIT,
    FIND_PATRON,
    REPAIR_KIT,
    DECOY,
    REST
}

var members: Array = []
var active_tasks: Dictionary = {} # Character: GlobalEnums.CrewTask

func get_available_members() -> Array:
    return members.filter(func(member: Node) -> bool: 
        return not active_tasks.has(member))

func add_member(character: Node) -> bool:
    if members.size() >= MAX_CREW_SIZE:
        return false
    members.append(character)
    crew_updated.emit()
    return true

func remove_member(character: Node) -> bool:
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

func assign_task(character: Node, task: int) -> bool:
    if not character in members or active_tasks.has(character):
        return false
    active_tasks[character] = task
    task_assigned.emit(character, task)
    return true

func complete_task(character: Node) -> void:
    if not active_tasks.has(character):
        return
    var completed_task = active_tasks[character]
    active_tasks.erase(character)
    task_completed.emit(character, completed_task)

func get_task_description(task: int) -> String:
    match task:
        CrewTask.TRADE: return "Search for profitable trade opportunities"
        CrewTask.EXPLORE: return "Scout the local area for opportunities"
        CrewTask.TRAIN: return "Improve skills through training"
        CrewTask.RECRUIT: return "Search for potential crew members"
        CrewTask.FIND_PATRON: return "Look for work opportunities"
        CrewTask.REPAIR_KIT: return "Repair and maintain equipment"
        CrewTask.DECOY: return "Create a diversion"
        CrewTask.REST: return "Recover from injuries or stress"
        _: return "Unknown task"
