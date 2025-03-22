@tool
extends Node

## Signals
signal resources_changed(new_total: int)
signal reputation_changed(new_value: int)
signal missions_completed(count: int)

## Variables
var campaign_type: int = 0
var total_resources: int = 0
var reputation: int = 0
var completed_missions: int = 0
var active_crew: Array[Dictionary] = []
var active_rivals: Array[Dictionary] = []
var equipment: Array[Dictionary] = []
var story_progress: int = 0

## Constructor
func _init(state = null) -> void:
    if state:
        # Initialize with game state if provided
        pass

## Get the total number of completed missions
func get_completed_missions_count() -> int:
    return completed_missions

## Get the total resources
func get_total_resources() -> int:
    return total_resources

## Get current reputation
func get_reputation() -> int:
    return reputation

## Get number of active crew members
func get_active_crew_count() -> int:
    return active_crew.size()

## Get number of active rivals
func get_active_rivals_count() -> int:
    return active_rivals.size()

## Check if crew has exploration capability
func has_exploration_capability() -> bool:
    for crew_member in active_crew:
        var skills = crew_member.get("skills", [])
        if skills is Array and "exploration" in skills:
            return true
    return false

## Check if crew has advanced equipment
func has_advanced_equipment() -> bool:
    for item in equipment:
        if item.get("tier", 0) >= 2:
            return true
    return false

## Check if there is story progress
func has_story_progress() -> bool:
    return story_progress > 0

## Add resources
func add_resources(amount: int) -> void:
    total_resources += amount
    resources_changed.emit(total_resources)

## Add reputation
func add_reputation(amount: int) -> void:
    reputation += amount
    reputation_changed.emit(reputation)

## Complete a mission
func complete_mission() -> void:
    completed_missions += 1
    missions_completed.emit(completed_missions)

## Add crew member
func add_crew_member(member: Dictionary) -> void:
    active_crew.push_back(member) # Using push_back instead of append for Array[Dictionary]

## Add rival
func add_rival(rival: Dictionary) -> void:
    active_rivals.push_back(rival) # Using push_back instead of append for Array[Dictionary]

## Add equipment
func add_equipment(item: Dictionary) -> void:
    equipment.push_back(item) # Using push_back instead of append for Array[Dictionary]

## Advance story progress
func advance_story() -> void:
    story_progress += 1