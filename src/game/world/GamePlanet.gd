@tool
extends Resource
class_name GamePlanet

const GameDataManager = preload("res://src/core/managers/GameDataManager.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameLocation = preload("res://src/game/world/GameLocation.gd")
const GameWorldTrait = preload("res://src/game/world/GameWorldTrait.gd")

signal planet_updated(property, value)

# Core properties
@export var planet_id: String = ""
@export var planet_name: String = ""
@export var sector: String = ""
@export var coordinates: Vector2 = Vector2.ZERO
@export var planet_type: int = GameEnums.PlanetType.NONE
@export var description: String = ""
@export var faction_type: int = GameEnums.FactionType.NEUTRAL
@export var environment_type: int = GameEnums.PlanetEnvironment.NONE
@export var world_traits: Array[GameWorldTrait] = []
@export var resources: Dictionary = {} # ResourceType: amount
@export var threats: Array[int] = []

# State tracking
@export var strife_level: int = GameEnums.StrifeType.NONE
@export var instability: int = GameEnums.StrifeType.NONE
@export var unity_progress: int = 0
@export var market_prices: Dictionary = {} # ItemType: price
@export var faction_control: int = GameEnums.FactionType.NONE
@export var locations: Array[GameLocation] = []
@export var visited: bool = false
@export var discovered: bool = false

# Data manager for loading traits
var _data_manager: GameDataManager = null

func _init() -> void:
    reset_state()
    
    # Create the data manager instance if needed
    if not Engine.is_editor_hint() and _data_manager == null:
        _data_manager = GameDataManager.new()
        _data_manager.load_world_traits()

func reset_state() -> void:
    resources.clear()
    threats.clear()
    world_traits.clear()
    market_prices.clear()
    strife_level = GameEnums.StrifeType.NONE
    instability = GameEnums.StrifeType.NONE
    unity_progress = 0

## Add a world trait to this planet by ID
func add_world_trait_by_id(trait_id: String) -> bool:
    if _data_manager == null:
        _data_manager = GameDataManager.new()
        _data_manager.load_world_traits()
        
    # Check if we already have this trait
    for trait_item in world_traits:
        if trait_item.trait_id == trait_id:
            return false
            
    # Create and initialize the new trait
    var new_trait = GameWorldTrait.new()
    if new_trait.initialize_from_id(trait_id):
        world_traits.append(new_trait)
        
        # Apply trait effects to planet
        _apply_trait_effects(new_trait)
        
        emit_signal("planet_updated", "world_traits", world_traits)
        return true
    
    return false

## Remove a world trait from this planet by ID
func remove_world_trait_by_id(trait_id: String) -> bool:
    for i in range(world_traits.size()):
        if world_traits[i].trait_id == trait_id:
            var removed_trait = world_traits[i]
            world_traits.remove_at(i)
            
            # Remove trait effects from planet
            _remove_trait_effects(removed_trait)
            
            emit_signal("planet_updated", "world_traits", world_traits)
            return true
    
    return false

## Apply the effects of a world trait to this planet
func _apply_trait_effects(world_trait: GameWorldTrait) -> void:
    # Apply resource modifiers
    for resource_key in world_trait.resource_modifiers:
        var resource_type = _get_resource_type_from_key(resource_key)
        if resource_type >= 0:
            var modifier = world_trait.resource_modifiers[resource_key]
            if not resources.has(resource_type):
                resources[resource_type] = 0
            resources[resource_type] += modifier

## Remove the effects of a world trait from this planet
func _remove_trait_effects(world_trait: GameWorldTrait) -> void:
    # Remove resource modifiers
    for resource_key in world_trait.resource_modifiers:
        var resource_type = _get_resource_type_from_key(resource_key)
        if resource_type >= 0 and resources.has(resource_type):
            var modifier = world_trait.resource_modifiers[resource_key]
            resources[resource_type] -= modifier
            if resources[resource_type] <= 0:
                resources.erase(resource_type)

## Convert a string resource key to a resource type enum value
func _get_resource_type_from_key(key: String) -> int:
    match key:
        "water": return 1
        "fuel": return GameEnums.ResourceType.FUEL
        "food": return 2
        "minerals": return 3
        "technology": return 4
        "medicine": return 5
        "exotic_materials": return 6
        _: return -1

func add_resource(resource_type: int, amount: int = 1) -> void:
    if not resource_type in range(GameEnums.ResourceType.size()):
        push_error("Invalid resource type provided")
        return
        
    if not resources.has(resource_type):
        resources[resource_type] = 0
    resources[resource_type] += amount
    
    emit_signal("planet_updated", "resources", resources)

func remove_resource(resource_type: int, amount: int = 1) -> bool:
    if not resource_type in range(GameEnums.ResourceType.size()):
        push_error("Invalid resource type provided")
        return false
        
    if not resources.has(resource_type) or resources[resource_type] < amount:
        return false
    resources[resource_type] -= amount
    if resources[resource_type] <= 0:
        resources.erase(resource_type)
    
    emit_signal("planet_updated", "resources", resources)
    return true

func add_threat(threat: int) -> void:
    if not threat in range(GameEnums.ThreatType.size()):
        push_error("Invalid threat type provided")
        return
        
    if not threat in threats:
        threats.append(threat)
        emit_signal("planet_updated", "threats", threats)

func remove_threat(threat: int) -> void:
    if not threat in range(GameEnums.ThreatType.size()):
        push_error("Invalid threat type provided")
        return
        
    var idx := threats.find(threat)
    if idx != -1:
        threats.remove_at(idx)
        emit_signal("planet_updated", "threats", threats)

func increase_strife() -> void:
    var current_index := strife_level
    if current_index < GameEnums.StrifeType.size() - 1:
        strife_level = current_index + 1
        emit_signal("planet_updated", "strife_level", strife_level)

func decrease_strife() -> void:
    if strife_level > GameEnums.StrifeType.NONE:
        strife_level -= 1
        emit_signal("planet_updated", "strife_level", strife_level)

func increase_instability() -> void:
    var current_index := instability
    if current_index < GameEnums.StrifeType.size() - 1:
        instability = current_index + 1
        emit_signal("planet_updated", "instability", instability)

func decrease_instability() -> void:
    if instability > GameEnums.StrifeType.NONE:
        instability -= 1
        emit_signal("planet_updated", "instability", instability)

func update_market_price(item_type: int, price: float) -> void:
    if not item_type in range(GameEnums.ItemType.size()):
        push_error("Invalid item type provided")
        return
        
    market_prices[item_type] = price
    emit_signal("planet_updated", "market_prices", market_prices)

func get_market_price(item_type: int) -> float:
    if not item_type in range(GameEnums.ItemType.size()):
        push_error("Invalid item type provided")
        return 0.0
        
    return market_prices.get(item_type, 0.0)

func has_trait(trait_id: String) -> bool:
    for t in world_traits:
        if t.trait_id == trait_id:
            return true
    return false

func has_threat(threat: int) -> bool:
    if not threat in range(GameEnums.ThreatType.size()):
        push_error("Invalid threat type provided")
        return false
        
    return threat in threats

func get_resource_amount(resource_type: int) -> int:
    if not resource_type in range(GameEnums.ResourceType.size()):
        push_error("Invalid resource type provided")
        return 0
        
    return resources.get(resource_type, 0)

func add_location(location: GameLocation) -> void:
    if not location in locations:
        locations.append(location)
        emit_signal("planet_updated", "locations", locations)

func remove_location(location: GameLocation) -> void:
    var idx = locations.find(location)
    if idx != -1:
        locations.remove_at(idx)
        emit_signal("planet_updated", "locations", locations)

func get_location_by_id(location_id: String) -> GameLocation:
    for location in locations:
        if location.location_id == location_id:
            return location
    return null

# Serialization
func serialize() -> Dictionary:
    var trait_data: Array = []
    for t in world_traits:
        trait_data.append(t.serialize())
        
    var threat_keys: Array[String] = []
    for t in threats:
        threat_keys.append(GameEnums.ThreatType.keys()[t])
    
    var location_data: Array = []
    for location in locations:
        location_data.append(location.serialize())
        
    return {
        "planet_id": planet_id,
        "planet_name": planet_name,
        "sector": sector,
        "coordinates": {"x": coordinates.x, "y": coordinates.y},
        "planet_type": GameEnums.PlanetType.keys()[planet_type],
        "description": description,
        "faction_type": GameEnums.FactionType.keys()[faction_type],
        "environment_type": GameEnums.PlanetEnvironment.keys()[environment_type],
        "world_traits": trait_data,
        "resources": resources,
        "threats": threat_keys,
        "strife_level": GameEnums.StrifeType.keys()[strife_level],
        "instability": GameEnums.StrifeType.keys()[instability],
        "unity_progress": unity_progress,
        "market_prices": market_prices,
        "faction_control": GameEnums.FactionType.keys()[faction_control],
        "locations": location_data,
        "visited": visited,
        "discovered": discovered
    }

static func deserialize(data: Dictionary) -> GamePlanet:
    var planet := GamePlanet.new()
    
    planet.planet_id = data.get("planet_id", "") as String
    planet.planet_name = data.get("planet_name", "") as String
    planet.sector = data.get("sector", "") as String
    
    var coords = data.get("coordinates", {})
    planet.coordinates = Vector2(coords.get("x", 0), coords.get("y", 0))
    
    # Validate and convert enum values
    var planet_type_str: String = data.get("planet_type", "NONE")
    if planet_type_str in GameEnums.PlanetType.keys():
        planet.planet_type = GameEnums.PlanetType[planet_type_str]
        
    var faction_type_str: String = data.get("faction_type", "NEUTRAL")
    if faction_type_str in GameEnums.FactionType.keys():
        planet.faction_type = GameEnums.FactionType[faction_type_str]
        
    var environment_type_str: String = data.get("environment_type", "NONE")
    if environment_type_str in GameEnums.PlanetEnvironment.keys():
        planet.environment_type = GameEnums.PlanetEnvironment[environment_type_str]
    
    planet.description = data.get("description", "") as String
    
    # Load world traits
    var traits_data = data.get("world_traits", [])
    for trait_data in traits_data:
        var world_trait = GameWorldTrait.deserialize(trait_data)
        planet.world_traits.append(world_trait)
    
    planet.resources = data.get("resources", {})
    
    # Convert and validate threat strings back to enum values
    var threats: Array = data.get("threats", [])
    for threat in threats:
        if threat in GameEnums.ThreatType.keys():
            planet.threats.append(GameEnums.ThreatType[threat])
    
    var strife_level_str: String = data.get("strife_level", "NONE")
    if strife_level_str in GameEnums.StrifeType.keys():
        planet.strife_level = GameEnums.StrifeType[strife_level_str]
        
    var instability_str: String = data.get("instability", "NONE")
    if instability_str in GameEnums.StrifeType.keys():
        planet.instability = GameEnums.StrifeType[instability_str]
        
    planet.unity_progress = data.get("unity_progress", 0) as int
    planet.market_prices = data.get("market_prices", {})
    
    var faction_control_str: String = data.get("faction_control", "NONE")
    if faction_control_str in GameEnums.FactionType.keys():
        planet.faction_control = GameEnums.FactionType[faction_control_str]
    
    # Load locations
    var locations_data = data.get("locations", [])
    for location_data in locations_data:
        var location = GameLocation.deserialize(location_data)
        planet.locations.append(location)
    
    planet.visited = data.get("visited", false)
    planet.discovered = data.get("discovered", false)
    
    return planet