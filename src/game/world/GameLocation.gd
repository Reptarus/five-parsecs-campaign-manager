@tool
extends Resource

class_name GameLocation

# Basic location properties
@export var location_id: String = ""
@export var location_name: String = ""
@export var location_type: int = 0
@export var description: String = ""
@export var coordinates: Vector2 = Vector2.ZERO
@export var connected_locations: Array[String] = []
@export var resources: Dictionary = {}
@export var points_of_interest: Array = []
@export var active_missions: Array = []
@export var world_traits: Array[GameWorldTrait] = []

# State tracking
@export var visited: bool = false
@export var discovered: bool = false
@export var danger_level: int = 1
@export var faction_control: int = 0
@export var strife_level: int = 0

# Market state
@export var market_state: int = MARKET_STATE_NORMAL
@export var market_prices: Dictionary = {}
@export var black_market_active: bool = false

# Constants for resource types
const RESOURCE_CREDITS = 0
const RESOURCE_SUPPLIES = 1
const RESOURCE_FUEL = 2
const RESOURCE_TECHNOLOGY = 3
const RESOURCE_WEAPONS = 4
const RESOURCE_LUXURY_GOODS = 5
const RESOURCE_MINERALS = 6
const RESOURCE_RARE_MATERIALS = 7
const RESOURCE_MEDICAL_SUPPLIES = 8

# Constants for market states
const MARKET_STATE_NORMAL = 0
const MARKET_STATE_BOOM = 1
const MARKET_STATE_BUST = 2
const MARKET_STATE_SHORTAGE = 3
const MARKET_STATE_SURPLUS = 4
const MARKET_STATE_BLOCKADE = 5

# Data manager for loading traits
var _data_manager: GameDataManager = null

# Signal for location updates
signal location_updated

func _init() -> void:
    # Initialize resources dictionary
    resources = {
        RESOURCE_CREDITS: 0,
        RESOURCE_SUPPLIES: 0,
        RESOURCE_FUEL: 0,
        RESOURCE_TECHNOLOGY: 0,
        RESOURCE_WEAPONS: 0,
        RESOURCE_LUXURY_GOODS: 0,
        RESOURCE_MINERALS: 0,
        RESOURCE_RARE_MATERIALS: 0,
        RESOURCE_MEDICAL_SUPPLIES: 0
    }
    
    # Initialize market prices
    update_market_state()
    
    # Create the data manager instance
    if not Engine.is_editor_hint():
        _data_manager = GameDataManager.new()
        _data_manager.load_all_data()

## Add a world trait to the location by its ID
func add_world_trait_by_id(trait_id: String) -> void:
    # Check if we already have this trait
    for t in world_traits:
        if t.trait_id == trait_id:
            return
    
    # Create and add the new trait
    var new_trait = GameWorldTrait.new()
    new_trait.initialize_from_id(trait_id)
    world_traits.append(new_trait)

## Remove a world trait from the location by its ID
func remove_world_trait_by_id(trait_id: String) -> void:
    for i in range(world_traits.size()):
        if world_traits[i].trait_id == trait_id:
            world_traits.remove_at(i)
            return

## Add a connected location by ID
func add_connected_location(location_id: String) -> void:
    if not location_id in connected_locations:
        connected_locations.append(location_id)

## Remove a connected location by ID
func remove_connected_location(location_id: String) -> void:
    if location_id in connected_locations:
        connected_locations.erase(location_id)

## Check if this location is connected to another location
func is_connected_to(location_id: String) -> bool:
    return location_id in connected_locations

## Add a mission to the location
func add_mission(mission) -> void:
    active_missions.append(mission)

## Remove a mission from the location
func remove_mission(mission_id: String) -> void:
    for i in range(active_missions.size()):
        if active_missions[i].mission_id == mission_id:
            active_missions.remove_at(i)
            return

## Add a point of interest to the location
func add_point_of_interest(poi) -> void:
    points_of_interest.append(poi)

## Remove a point of interest from the location
func remove_point_of_interest(poi_id: String) -> void:
    for i in range(points_of_interest.size()):
        if points_of_interest[i].poi_id == poi_id:
            points_of_interest.remove_at(i)
            return

## Update market prices based on market state and modifiers
func update_market_state() -> void:
    # Base prices
    var base_prices = {
        RESOURCE_SUPPLIES: 10,
        RESOURCE_FUEL: 15,
        RESOURCE_TECHNOLOGY: 50,
        RESOURCE_WEAPONS: 75,
        RESOURCE_LUXURY_GOODS: 100,
        RESOURCE_MINERALS: 25,
        RESOURCE_RARE_MATERIALS: 150,
        RESOURCE_MEDICAL_SUPPLIES: 40
    }
    
    # Apply market state modifiers
    var state_modifiers = {
        MARKET_STATE_NORMAL: 1.0,
        MARKET_STATE_BOOM: 1.2,
        MARKET_STATE_BUST: 0.8,
        MARKET_STATE_SHORTAGE: 1.5,
        MARKET_STATE_SURPLUS: 0.7,
        MARKET_STATE_BLOCKADE: 2.0
    }
    
    var state_modifier = state_modifiers.get(market_state, 1.0)
    
    # Calculate final prices
    for resource_type in base_prices:
        var base_price = base_prices[resource_type]
        var trait_modifier = get_resource_modifier(resource_type)
        
        # Apply modifiers
        var final_price = base_price * state_modifier * (1.0 + trait_modifier)
        
        # Add some randomness (±10%)
        var random_factor = randf_range(0.9, 1.1)
        final_price *= random_factor
        
        # Round to nearest integer
        market_prices[resource_type] = int(final_price)
    
    # Emit signal to notify of market update
    location_updated.emit()

## Add resources to the location
func add_resource(resource_type: int, amount: int = 1) -> void:
    if resource_type in resources:
        resources[resource_type] += amount
    else:
        resources[resource_type] = amount
    location_updated.emit()

## Remove resources from the location
func remove_resource(resource_type: int, amount: int = 1) -> bool:
    if resource_type in resources and resources[resource_type] >= amount:
        resources[resource_type] -= amount
        if resources[resource_type] <= 0:
            resources.erase(resource_type)
        location_updated.emit()
        return true
    return false

## Get the total resource modifier from all world traits
func get_resource_modifier(resource_type: String) -> float:
    var total_modifier = 0.0
    for trait_item in world_traits:
        total_modifier += trait_item.get_resource_modifier(resource_type)
    return total_modifier

## Get the total modifier value for a specific encounter type from all world traits
func get_encounter_modifier(encounter_type: String) -> float:
    var total_modifier = 0.0
    for trait_item in world_traits:
        total_modifier += trait_item.get_encounter_modifier(encounter_type)
    return total_modifier

## Check if the location has a specific tag from any of its world traits
func has_tag(tag: String) -> bool:
    for trait_item in world_traits:
        if trait_item.has_tag(tag):
            return true
    return false

## Compatibility method for FiveParsecsLocation.has_special_feature
## This allows the WorldEconomyManager to work with both location types
func has_special_feature(feature_name: String) -> bool:
    # Map old feature names to new tag names
    var feature_to_tag = {
        "industrial": "industrial",
        "frontier": "frontier",
        "trade": "trade",
        "pirate": "pirate",
        "free_port": "free_port",
        "corporate": "corporate",
        # Add more mappings as needed
    }
    
    # Check if we have a mapping for this feature
    if feature_name in feature_to_tag:
        return has_tag(feature_to_tag[feature_name])
    
    # Fallback to direct tag check
    return has_tag(feature_name)

## Serialize the location's data into a dictionary
func serialize() -> Dictionary:
    var trait_data = []
    for trait_item in world_traits:
        trait_data.append(trait_item.serialize())
    
    var poi_data = []
    for poi in points_of_interest:
        poi_data.append(poi.serialize())
    
    var mission_data = []
    for mission in active_missions:
        mission_data.append(mission.serialize())
    
    return {
        "location_id": location_id,
        "location_name": location_name,
        "location_type": location_type,
        "description": description,
        "coordinates": {"x": coordinates.x, "y": coordinates.y},
        "connected_locations": connected_locations,
        "resources": resources,
        "points_of_interest": poi_data,
        "active_missions": mission_data,
        "world_traits": trait_data,
        "visited": visited,
        "discovered": discovered,
        "danger_level": danger_level,
        "faction_control": faction_control,
        "strife_level": strife_level,
        "market_state": market_state,
        "market_prices": market_prices,
        "black_market_active": black_market_active
    }

## Create a GameLocation instance from serialized data
static func deserialize(data: Dictionary) -> GameLocation:
    var location = GameLocation.new()
    
    location.location_id = data.get("location_id", "")
    location.location_name = data.get("location_name", "")
    location.location_type = data.get("location_type", 0)
    location.description = data.get("description", "")
    
    var coords = data.get("coordinates", {"x": 0, "y": 0})
    location.coordinates = Vector2(coords.get("x", 0), coords.get("y", 0))
    
    location.connected_locations = data.get("connected_locations", [])
    location.resources = data.get("resources", {})
    
    # Deserialize world traits
    var trait_data = data.get("world_traits", [])
    for i in range(trait_data.size()):
        var t_dict = trait_data[i]
        var new_trait = GameWorldTrait.new()
        new_trait.initialize_from_data(t_dict)
        location.world_traits.append(new_trait)
    
    location.visited = data.get("visited", false)
    location.discovered = data.get("discovered", false)
    location.danger_level = data.get("danger_level", 1)
    location.faction_control = data.get("faction_control", 0)
    location.strife_level = data.get("strife_level", 0)
    location.market_state = data.get("market_state", MARKET_STATE_NORMAL)
    location.market_prices = data.get("market_prices", {})
    location.black_market_active = data.get("black_market_active", false)
    
    # Load points of interest and missions if needed
    # This would require additional deserialization logic for those types
    
    return location