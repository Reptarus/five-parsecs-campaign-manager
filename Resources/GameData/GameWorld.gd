class_name GameWorld
extends SerializableResource

signal location_changed(new_location: Location)
signal resources_updated(resources: Dictionary)

@export var current_location: Location
@export var discovered_locations: Array[Location] = []
@export var available_missions: Array[Mission] = []
@export var world_resources: Dictionary = {}
@export var danger_level: float = 0.0

func serialize() -> Dictionary:
    return {
        "current_location": current_location.serialize() if current_location else null,
        "discovered_locations": discovered_locations.map(func(loc): return loc.serialize()),
        "available_missions": available_missions.map(func(mission): return mission.serialize()),
        "world_resources": world_resources,
        "danger_level": danger_level
    }

func deserialize(data: Dictionary) -> void:
    if data.has("current_location"):
        var loc = Location.new()
        loc.deserialize(data.current_location)
        current_location = loc
        
    discovered_locations.clear()
    for loc_data in data.get("discovered_locations", []):
        var loc = Location.new()
        loc.deserialize(loc_data)
        discovered_locations.append(loc)
        
    available_missions.clear()
    for mission_data in data.get("available_missions", []):
        var mission = Mission.new()
        mission.deserialize(mission_data)
        available_missions.append(mission)
        
    world_resources = data.get("world_resources", {})
    danger_level = data.get("danger_level", 0.0)