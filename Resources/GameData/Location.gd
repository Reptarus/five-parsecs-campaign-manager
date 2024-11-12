class_name Location
extends Resource

@export var name: String
@export var type: GlobalEnums.TerrainType
@export var faction: GlobalEnums.FactionType
@export var instability: GlobalEnums.FringeWorldInstability

var traits: Array[GlobalEnums.WorldTrait] = []
var available_missions: Array[Mission] = []
var local_events: Array[Dictionary] = []
var resources: Dictionary = {}

func _init(location_name: String = "", 
          location_type: GlobalEnums.TerrainType = GlobalEnums.TerrainType.CITY,
          location_faction: GlobalEnums.FactionType = GlobalEnums.FactionType.NEUTRAL,
          location_instability: GlobalEnums.FringeWorldInstability = GlobalEnums.FringeWorldInstability.NONE) -> void:
    name = location_name
    type = location_type
    faction = location_faction
    instability = location_instability

func get_traits() -> Array[GlobalEnums.WorldTrait]:
    return traits

func serialize() -> Dictionary:
    var mission_data = []
    for mission in available_missions:
        mission_data.append(mission.serialize())
        
    return {
        "name": name,
        "type": type,
        "faction": faction,
        "instability": instability,
        "traits": traits,
        "available_missions": mission_data,
        "local_events": local_events,
        "resources": resources
    }

static func deserialize(data: Dictionary) -> Location:
    var location = Location.new(
        data.get("name", ""),
        data.get("type", GlobalEnums.TerrainType.CITY),
        data.get("faction", GlobalEnums.FactionType.NEUTRAL),
        data.get("instability", GlobalEnums.FringeWorldInstability.NONE)
    )
    
    location.traits = data.get("traits", [])
    
    if data.has("available_missions"):
        for mission_data in data.get("available_missions", []):
            location.available_missions.append(Mission.deserialize(mission_data))
    
    location.local_events = data.get("local_events", [])
    location.resources = data.get("resources", {})
    
    return location
