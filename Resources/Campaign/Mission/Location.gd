class_name Location
extends Resource

@export var name: String
@export var type: GlobalEnums.TerrainType
@export var faction: GlobalEnums.FactionType
@export var instability: int = 0  # Base instability level

# Instability System
var instability_factors: Dictionary = {}
var current_events: Array[Dictionary] = []
var threat_level: int = 0
var stability_modifiers: Array[Dictionary] = []

# World Data
var traits: Array[String] = []
var available_missions: Array[MissionData] = []
var local_events: Array[Dictionary] = []
var resources: Dictionary = {}

func _init(location_name: String = "", 
          location_type: GlobalEnums.TerrainType = GlobalEnums.TerrainType.CITY,
          location_faction: GlobalEnums.FactionType = GlobalEnums.FactionType.NEUTRAL,
          location_instability: int = 0) -> void:
    name = location_name
    type = location_type
    faction = faction
    instability = location_instability
    _initialize_instability_system()

func _initialize_instability_system() -> void:
    instability_factors = {
        "faction_conflict": 0,
        "criminal_activity": 0,
        "economic_stress": 0,
        "social_unrest": 0,
        "external_threats": 0
    }

func modify_instability(factor: String, amount: int) -> void:
    if instability_factors.has(factor):
        instability_factors[factor] = clampi(instability_factors[factor] + amount, 0, 5)
        _recalculate_instability()

func add_stability_modifier(modifier: Dictionary) -> void:
    stability_modifiers.append(modifier)
    _recalculate_instability()

func remove_stability_modifier(modifier_id: String) -> void:
    stability_modifiers = stability_modifiers.filter(
        func(mod): return mod.id != modifier_id
    )
    _recalculate_instability()

func _recalculate_instability() -> void:
    var base_instability = instability_factors.values().reduce(
        func(acc, val): return acc + val, 0
    ) / float(instability_factors.size())
    
    # Apply modifiers
    for modifier in stability_modifiers:
        if modifier.has("multiplier"):
            base_instability *= modifier.multiplier
        if modifier.has("flat_modifier"):
            base_instability += modifier.flat_modifier
    
    instability = roundi(base_instability)
    threat_level = _calculate_threat_level()

func _calculate_threat_level() -> int:
    var threat = 1  # Base threat level
    
    # Factor in instability
    if instability >= 4:
        threat += 2
    elif instability >= 2:
        threat += 1
    
    # Factor in faction hostility
    if faction == GlobalEnums.FactionType.HOSTILE:
        threat += 1
    
    # Factor in active events
    for event in current_events:
        if event.get("increases_threat", false):
            threat += 1
    
    return clampi(threat, 1, 5)

func get_traits() -> Array[String]:
    return traits

func add_event(event: Dictionary) -> void:
    current_events.append(event)
    if event.has("instability_effect"):
        modify_instability(event.instability_type, event.instability_effect)

func remove_event(event_id: String) -> void:
    current_events = current_events.filter(
        func(event): return event.id != event_id
    )
    _recalculate_instability()

func get_current_threats() -> Array[Dictionary]:
    var threats: Array[Dictionary] = []
    
    if instability >= 3:
        threats.append({
            "type": "civil_unrest",
            "severity": instability - 2
        })
    
    for event in current_events:
        if event.has("threat"):
            threats.append(event.threat)
    
    return threats

func serialize() -> Dictionary:
    var mission_data = []
    for mission in available_missions:
        mission_data.append(mission.serialize())
        
    return {
        "name": name,
        "type": type,
        "faction": faction,
        "instability": instability,
        "instability_factors": instability_factors,
        "stability_modifiers": stability_modifiers,
        "current_events": current_events,
        "threat_level": threat_level,
        "traits": traits,
        "available_missions": mission_data,
        "local_events": local_events,
        "resources": resources
    }

static func deserialize(data: Dictionary) -> Location:
    var location = Location.new()
    
    if data.has("available_missions"):
        for mission_data in data.get("available_missions", []):
            location.available_missions.append(MissionData.deserialize(mission_data))
    
    location.local_events = data.get("local_events", [])
    location.resources = data.get("resources", {})
    
    return location
