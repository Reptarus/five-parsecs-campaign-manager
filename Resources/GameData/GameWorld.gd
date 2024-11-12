class_name GameWorld
extends Resource

signal location_changed(new_location: Location)
signal resources_updated(resources: Dictionary)

var current_location: Location
var discovered_locations: Array[Location] = []
var available_missions: Array[Mission] = []
var world_resources: Dictionary = {}
var danger_level: float = 0.0

func _init() -> void:
    pass

static func deserialize(data: Dictionary) -> GameWorld:
    var world = GameWorld.new()
    
    if data.has("current_location"):
        world.current_location = Location.deserialize(data.current_location)
    
    if data.has("discovered_locations"):
        for location_data in data.discovered_locations:
            world.discovered_locations.append(Location.deserialize(location_data))
    
    if data.has("available_missions"):
        for mission_data in data.available_missions:
            world.available_missions.append(Mission.deserialize(mission_data))
    
    world.world_resources = data.get("world_resources", {})
    world.danger_level = data.get("danger_level", 0.0)
    
    return world

func serialize() -> Dictionary:
    var serialized_locations = []
    for location in discovered_locations:
        serialized_locations.append(location.serialize())
        
    var serialized_missions = []
    for mission in available_missions:
        serialized_missions.append(mission.serialize())
    
    return {
        "current_location": current_location.serialize() if current_location else null,
        "discovered_locations": serialized_locations,
        "available_missions": serialized_missions,
        "world_resources": world_resources,
        "danger_level": danger_level
    }

func add_location(location: Location) -> void:
    if not location in discovered_locations:
        discovered_locations.append(location)

func set_current_location(location: Location) -> void:
    current_location = location
    location_changed.emit(location)

func update_resources(new_resources: Dictionary) -> void:
    world_resources = new_resources
    resources_updated.emit(world_resources)

func get_danger_level() -> float:
    return danger_level

func update_danger_level(value: float) -> void:
    danger_level = value 