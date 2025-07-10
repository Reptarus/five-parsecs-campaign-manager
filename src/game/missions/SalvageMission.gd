# SalvageMission.gd
class_name SalvageMission extends Mission

@export var tension_track: int = 0

func _init():
    super._init()
    mission_title = "Salvage Job"
    mission_description = "An exploration-focused mission to find valuable salvage."

func start_exploration_round() -> void:
    print("Starting exploration round...")
    # Logic for exploring points of interest, finding salvage, etc.

func increase_tension() -> void:
    tension_track += 1
    print(str("Tension increased to: ", tension_track))
    # Logic for triggering hostile encounters based on tension

func discover_salvage(item: Resource, location: Vector2) -> void:
    print(str("Discovered salvage: ", item.resource_name, " at ", location))
    # Signal for salvage discovery
    # emit_signal("salvage_discovery", item, location)