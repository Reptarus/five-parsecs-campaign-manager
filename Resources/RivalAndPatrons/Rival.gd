class_name Rival
extends Resource

signal hostility_changed(new_value: int)
signal strength_changed(new_value: int)

@export var name: String:
    get:
        return name
    set(value):
        if value.strip_edges().is_empty():
            push_error("Rival name cannot be empty")
            return
        name = value

@export var location: Location = null:
    get:
        return location
    set(value):
        location = value
        notify_property_list_changed()

@export var threat_level: GlobalEnums.RivalThreatLevel = GlobalEnums.RivalThreatLevel.LOW:
    get:
        return threat_level
    set(value):
        threat_level = value
        economic_influence = calculate_economic_influence()
        strength_changed.emit(threat_level)

@export_range(0, 100) var hostility: int = 0:
    get:
        return hostility
    set(value):
        hostility = clamp(value, 0, 100)
        hostility_changed.emit(hostility)

@export var economic_influence: float = 1.0

func calculate_economic_influence() -> float:
    # 25% impact increase per threat level
    return 1.0 + (threat_level as int) * 0.25
