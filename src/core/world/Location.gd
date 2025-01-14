class_name Location
extends Resource

# Resource type constants
const RESOURCE_CREDITS = 0
const RESOURCE_SUPPLIES = 1
const RESOURCE_MINERALS = 2
const RESOURCE_TECHNOLOGY = 3
const RESOURCE_MEDICAL_SUPPLIES = 4
const RESOURCE_WEAPONS = 5
const RESOURCE_RARE_MATERIALS = 6
const RESOURCE_LUXURY_GOODS = 7
const RESOURCE_FUEL = 8

# Market state constants
const MARKET_NORMAL = 0
const MARKET_CRISIS = 1
const MARKET_BOOM = 2
const MARKET_RESTRICTED = 3

@export var name: String = ""
@export var coordinates: Vector2 = Vector2.ZERO
@export var type: String = ""
@export var description: String = ""
@export var faction: String = ""
@export var danger_level: int = 1
@export var resources: Dictionary = {}
@export var connected_locations: Array[String] = []
@export var available_missions: Array = []
@export var local_events: Array = []
@export var market_modifiers: Dictionary = {}
@export var special_features: Array = []

# Economy and trade
@export var market_state: int = MARKET_NORMAL
@export var trade_goods: Array = []
@export var black_market_active: bool = false
@export var price_modifiers: Dictionary = {}

# Status and conditions
@export var is_discovered: bool = false
@export var is_accessible: bool = true
@export var current_threats: Array = []
@export var active_effects: Array = []

func _init() -> void:
    if not resources.is_empty():
        return
        
    resources = {
        RESOURCE_CREDITS: 0,
        RESOURCE_SUPPLIES: 0,
        RESOURCE_MINERALS: 0,
        RESOURCE_TECHNOLOGY: 0,
        RESOURCE_MEDICAL_SUPPLIES: 0,
        RESOURCE_WEAPONS: 0,
        RESOURCE_RARE_MATERIALS: 0,
        RESOURCE_LUXURY_GOODS: 0,
        RESOURCE_FUEL: 0
    }

func add_connected_location(location_name: String) -> void:
    if not connected_locations.has(location_name):
        connected_locations.append(location_name)

func remove_connected_location(location_name: String) -> void:
    connected_locations.erase(location_name)

func is_connected_to(location_name: String) -> bool:
    return connected_locations.has(location_name)

func add_mission(mission_data: Dictionary) -> void:
    if not available_missions.has(mission_data):
        available_missions.append(mission_data)

func remove_mission(mission_data: Dictionary) -> void:
    available_missions.erase(mission_data)

func add_event(event_data: Dictionary) -> void:
    if not local_events.has(event_data):
        local_events.append(event_data)

func clear_expired_events() -> void:
    var current_events = []
    for event in local_events:
        if not event.get("expired", false):
            current_events.append(event)
    local_events = current_events

func update_market_state() -> void:
    # Update prices based on market state and modifiers
    for resource in resources.keys():
        var base_price = resources[resource]
        var modifier = 1.0
        
        # Apply market state modifier
        match market_state:
            MARKET_CRISIS:
                modifier *= 2.0
            MARKET_BOOM:
                modifier *= 0.5
            MARKET_RESTRICTED:
                modifier *= 1.5
        
        # Apply local modifiers
        if resource in market_modifiers:
            modifier *= market_modifiers[resource]
            
        # Update price
        price_modifiers[resource] = modifier

func get_travel_cost_to(destination: Location) -> float:
    var base_cost = 10.0
    var distance = coordinates.distance_to(destination.coordinates)
    var danger_modifier = (danger_level + destination.danger_level) * 0.1
    
    return base_cost + (distance * 2) + (base_cost * danger_modifier)

func get_resource_price(resource_type: GameEnums.ResourceType) -> float:
    var base_price = resources.get(resource_type, 0)
    var modifier = price_modifiers.get(resource_type, 1.0)
    return base_price * modifier

func add_threat(threat_data: Dictionary) -> void:
    if not current_threats.has(threat_data):
        current_threats.append(threat_data)
        # Update danger level based on threats
        danger_level = maxi(danger_level, threat_data.get("threat_level", 1))

func remove_threat(threat_data: Dictionary) -> void:
    current_threats.erase(threat_data)
    # Recalculate danger level
    danger_level = 1
    for threat in current_threats:
        danger_level = maxi(danger_level, threat.get("threat_level", 1))

func add_special_feature(feature: String) -> void:
    if not special_features.has(feature):
        special_features.append(feature)

func has_special_feature(feature: String) -> bool:
    return special_features.has(feature)

func serialize() -> Dictionary:
    return {
        "name": name,
        "coordinates": {"x": coordinates.x, "y": coordinates.y},
        "type": type,
        "description": description,
        "faction": faction,
        "danger_level": danger_level,
        "resources": resources,
        "connected_locations": connected_locations,
        "available_missions": available_missions,
        "local_events": local_events,
        "market_modifiers": market_modifiers,
        "special_features": special_features,
        "market_state": market_state,
        "trade_goods": trade_goods,
        "black_market_active": black_market_active,
        "price_modifiers": price_modifiers,
        "is_discovered": is_discovered,
        "is_accessible": is_accessible,
        "current_threats": current_threats,
        "active_effects": active_effects
    }

static func deserialize(data: Dictionary) -> Location:
    var location = Location.new()
    location.name = data.get("name", "")
    location.coordinates = Vector2(data.get("coordinates", {}).get("x", 0), data.get("coordinates", {}).get("y", 0))
    location.type = data.get("type", "")
    location.description = data.get("description", "")
    location.faction = data.get("faction", "")
    location.danger_level = data.get("danger_level", 1)
    location.resources = data.get("resources", {})
    location.connected_locations = data.get("connected_locations", [])
    location.available_missions = data.get("available_missions", [])
    location.local_events = data.get("local_events", [])
    location.market_modifiers = data.get("market_modifiers", {})
    location.special_features = data.get("special_features", [])
    location.market_state = data.get("market_state", MARKET_NORMAL)
    location.trade_goods = data.get("trade_goods", [])
    location.black_market_active = data.get("black_market_active", false)
    location.price_modifiers = data.get("price_modifiers", {})
    location.is_discovered = data.get("is_discovered", false)
    location.is_accessible = data.get("is_accessible", true)
    location.current_threats = data.get("current_threats", [])
    location.active_effects = data.get("active_effects", [])
    return location