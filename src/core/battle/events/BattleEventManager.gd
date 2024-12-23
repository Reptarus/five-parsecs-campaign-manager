extends Node

signal event_triggered(event: Dictionary)
signal event_resolved(event: Dictionary, results: Dictionary)
signal deployment_condition_changed(condition: Dictionary)
signal notable_sight_discovered(sight: Dictionary)

# Core rules event types
enum BattleEventType {
    NONE,
    COMBAT,
    MOVEMENT,
    OBJECTIVE,
    DEPLOYMENT,
    REACTION,
    SPECIAL
}

# Core rules event categories
enum EventCategory {
    DEPLOYMENT,
    OBJECTIVE,
    ENEMY,
    NOTABLE_SIGHT,
    COMBAT,
    RESOLUTION
}

var active_events: Array[Dictionary] = []
var event_queue: Array[Dictionary] = []
var current_event: Dictionary = {}
var deployment_condition: Dictionary = {}
var notable_sights: Array[Dictionary] = []

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE

# Core rules deployment conditions
func set_deployment_condition(mission_type: int, roll: int) -> void:
    var condition := _get_deployment_condition(mission_type, roll)
    deployment_condition = condition
    deployment_condition_changed.emit(condition)

func _get_deployment_condition(mission_type: int, roll: int) -> Dictionary:
    # Implementation based on core rules table
    var condition := {}
    match mission_type:
        GlobalEnums.MissionType.PATRON:
            if roll >= 91:
                condition = {"type": "GLOOMY", "visibility": 9}
            elif roll >= 86:
                condition = {"type": "CAUGHT_OFF_GUARD", "first_round_slow": true}
        # Add other mission types and conditions
    return condition

# Core rules notable sights
func check_for_notable_sight(mission_type: int, roll: int) -> void:
    var sight := _get_notable_sight(mission_type, roll)
    if not sight.is_empty():
        notable_sights.append(sight)
        notable_sight_discovered.emit(sight)

func _get_notable_sight(mission_type: int, roll: int) -> Dictionary:
    # Implementation based on core rules table
    var sight := {}
    match mission_type:
        GlobalEnums.MissionType.PATRON:
            if roll >= 91:
                sight = {"type": "CURIOUS_ITEM", "loot_roll_required": true}
            elif roll >= 81:
                sight = {"type": "PECULIAR_ITEM", "xp_bonus": 2}
    return sight

# Updated event handling
func add_event(event: Dictionary) -> void:
    if not _validate_event(event):
        push_error("BattleEventManager: Invalid event format")
        return
    
    event_queue.append(event)
    _process_next_event()

func _validate_event(event: Dictionary) -> bool:
    return event.has_all(["type", "category", "data"])

func _process_next_event() -> void:
    if event_queue.is_empty() or not current_event.is_empty():
        return
    
    current_event = event_queue.pop_front()
    active_events.append(current_event)
    event_triggered.emit(current_event)

func resolve_current_event(results: Dictionary) -> void:
    if current_event.is_empty():
        return
    
    event_resolved.emit(current_event, results)
    active_events.erase(current_event)
    current_event = {}
    _process_next_event()

func clear_events() -> void:
    active_events.clear()
    event_queue.clear()
    current_event = {}

func get_active_events() -> Array[Dictionary]:
    return active_events

func has_pending_events() -> bool:
    return not event_queue.is_empty() or not current_event.is_empty()

func serialize() -> Dictionary:
    return {
        "active_events": active_events,
        "event_queue": event_queue,
        "current_event": current_event,
        "deployment_condition": deployment_condition,
        "notable_sights": notable_sights
    }

func deserialize(data: Dictionary) -> void:
    active_events = data.get("active_events", [])
    event_queue = data.get("event_queue", [])
    current_event = data.get("current_event", {})
    deployment_condition = data.get("deployment_condition", {})
    notable_sights = data.get("notable_sights", [])
