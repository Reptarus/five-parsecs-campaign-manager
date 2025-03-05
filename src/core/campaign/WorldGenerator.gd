@tool
extends Node

## World Generator for Five Parsecs From Home
## Implements world generation from rulebook (p.80-86)

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameDataManager = preload("res://src/core/managers/GameDataManager.gd")

# Signal declarations
signal world_generated(world_data: Dictionary)
signal location_discovered(location_data: Dictionary)

# Data files
const PLANET_TYPES_PATH = "res://data/planet_types.json"
const LOCATION_TYPES_PATH = "res://data/location_types.json"
const WORLD_TRAITS_PATH = "res://data/world_traits.json"

# Loaded data
var _planet_types: Array = []
var _location_types: Array = []
var _world_traits: Array = []
var _world_data: Dictionary = {}
var _sector_data: Array[Dictionary] = []
var _data_manager: Object

# Generator settings
var _danger_level_modifier: int = 0
var _use_specific_planet_type: bool = false
var _specific_planet_type: String = ""

func _init() -> void:
    _data_manager = GameDataManager.get_instance()
    GameDataManager.ensure_data_loaded()
    _load_data()

func _ready() -> void:
    pass

## Load all required data from JSON files
func _load_data() -> void:
    # Load planet types
    var planet_data = _data_manager.load_json_file(PLANET_TYPES_PATH)
    if planet_data and planet_data.has("planet_types"):
        _planet_types = planet_data["planet_types"]
    else:
        push_error("Failed to load planet types data")
    
    # Load location types
    var location_data = _data_manager.load_json_file(LOCATION_TYPES_PATH)
    if location_data and location_data.has("location_types"):
        _location_types = location_data["location_types"]
    else:
        push_error("Failed to load location types data")
    
    # Load world traits
    var trait_data = _data_manager.load_json_file(WORLD_TRAITS_PATH)
    if trait_data and trait_data.has("world_traits"):
        _world_traits = trait_data["world_traits"]
    else:
        push_error("Failed to load world traits data")

## Generate a new world according to the rulebook
func generate_world(campaign_turn: int = 1) -> Dictionary:
    # Step 1: Generate planet type and basic info (rulebook p.80)
    var planet_type = _generate_planet_type()
    
    # Step 2: Generate planet name
    var planet_name = _generate_planet_name(planet_type)
    
    # Step 3: Determine danger level (rulebook p.80-81)
    var danger_level = _calculate_danger_level(campaign_turn, planet_type)
    
    # Step 4: Generate planetary traits (rulebook p.81-82)
    var traits = _generate_planetary_traits(planet_type)
    
    # Step 5: Generate locations (rulebook p.82-84)
    var locations = _generate_locations(planet_type, danger_level)
    
    # Step 6: Determine special features
    var special_features = _determine_special_features(planet_type, danger_level)
    
    # Create the world data dictionary
    var world_data = {
        "id": "world_" + str(Time.get_unix_time_from_system()),
        "name": planet_name,
        "type": planet_type.get("type", "Unknown"),
        "type_name": planet_type.get("name", "Unknown Planet"),
        "danger_level": danger_level,
        "traits": traits,
        "locations": locations,
        "special_features": special_features,
        "discovered_on_turn": campaign_turn,
        "visited_locations": [],
        "resources_extracted": 0,
        "mission_count": 0,
        "has_patron": false
    }
    
    # Emit signal
    world_generated.emit(world_data)
    
    return world_data

## Generate a planet type according to rulebook tables (p.80)
func _generate_planet_type() -> Dictionary:
    if _use_specific_planet_type and _specific_planet_type != "":
        # Use the specified planet type if set
        for planet in _planet_types:
            if planet.get("type", "") == _specific_planet_type:
                return planet
    
    # Otherwise, roll on the table
    var roll = randi() % 100 + 1
    
    for planet in _planet_types:
        var range_min = planet.get("range_min", 0)
        var range_max = planet.get("range_max", 0)
        
        if roll >= range_min and roll <= range_max:
            return planet
    
    # Fallback to first planet type if something went wrong
    if _planet_types.size() > 0:
        return _planet_types[0]
    
    # Ultimate fallback if no data loaded
    return {
        "type": "FRONTIER_WORLD",
        "name": "Frontier World",
        "description": "A rugged frontier settlement.",
        "base_danger": 2
    }

## Generate a planet name
func _generate_planet_name(planet_type: Dictionary) -> String:
    # Generate a name based on planet type
    var base_names = planet_type.get("name_prefixes", ["Alpha", "Beta", "Gamma", "Delta"])
    var suffixes = planet_type.get("name_suffixes", ["Prime", "II", "III", "Major", "Minor"])
    
    var base_name = base_names[randi() % base_names.size()]
    var suffix = suffixes[randi() % suffixes.size()]
    
    return base_name + " " + suffix

## Calculate danger level based on campaign turn and planet type (p.80-81)
func _calculate_danger_level(campaign_turn: int, planet_type: Dictionary) -> int:
    var base_danger = planet_type.get("base_danger", 2)
    
    # Adjust for campaign turn (increasing danger over time)
    var turn_modifier = floor(campaign_turn / 5)
    
    # Apply global modifier
    var danger_level = base_danger + turn_modifier + _danger_level_modifier
    
    # Clamp between 1 and 6 (as per rulebook)
    return clamp(danger_level, 1, 6)

## Generate planetary traits based on planet type (p.81-82)
func _generate_planetary_traits(planet_type: Dictionary) -> Array:
    var traits = []
    var trait_count = 1 + (randi() % 2) # 1-2 traits as per rulebook
    
    var available_traits = _world_traits.duplicate()
    
    # Add any mandatory traits for this planet type
    var mandatory_traits = planet_type.get("mandatory_traits", [])
    for trait_id in mandatory_traits:
        traits.append(trait_id)
        # Remove from available to avoid duplicates
        for i in range(available_traits.size() - 1, -1, -1):
            if available_traits[i].get("id") == trait_id:
                available_traits.remove_at(i)
                break
    
    # Add random traits
    for _i in range(trait_count):
        if available_traits.size() == 0:
            break
            
        var index = randi() % available_traits.size()
        traits.append(available_traits[index].get("id"))
        available_traits.remove_at(index)
    
    return traits

## Generate locations for the world (p.82-84)
func _generate_locations(planet_type: Dictionary, danger_level: int) -> Array:
    var locations = []
    
    # Determine number of locations (rulebook p.82)
    var location_count = _determine_location_count(planet_type)
    
    # Generate each location
    for _i in range(location_count):
        # Filter location types by planet compatibility
        var compatible_locations = []
        for location in _location_types:
            var compatible_planets = location.get("compatible_planets", [])
            if compatible_planets.size() == 0 or planet_type.get("type", "") in compatible_planets:
                compatible_locations.append(location)
        
        if compatible_locations.size() == 0:
            continue
        
        # Select a random compatible location
        var location_type = compatible_locations[randi() % compatible_locations.size()]
        
        # Generate location details
        var location_data = {
            "id": "loc_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000),
            "type": location_type.get("type", ""),
            "name": location_type.get("name", "Unknown Location"),
            "description": location_type.get("description", ""),
            "danger_mod": location_type.get("danger_mod", 0),
            "resources": location_type.get("resource_value", 0) * danger_level,
            "explored": false,
            "special_features": _generate_location_features(location_type, danger_level)
        }
        
        locations.append(location_data)
    
    return locations

## Determine the number of locations to generate (p.82)
func _determine_location_count(planet_type: Dictionary) -> int:
    var base_count = planet_type.get("base_location_count", 2)
    
    # Roll for additional locations
    var additional = 0
    if randf() < 0.4: # 40% chance for extra location
        additional = 1
    
    return base_count + additional

## Generate special features for a location (p.83-84)
func _generate_location_features(location_type: Dictionary, danger_level: int) -> Array:
    var features = []
    
    # Check for mandatory features
    var mandatory_features = location_type.get("mandatory_features", [])
    for feature in mandatory_features:
        features.append(feature)
    
    # Roll for special features
    if randf() < 0.25 + (danger_level * 0.05): # Higher chance at higher danger
        var possible_features = location_type.get("possible_features", [])
        if possible_features.size() > 0:
            features.append(possible_features[randi() % possible_features.size()])
    
    return features

## Determine special features for the planet based on type and danger
func _determine_special_features(planet_type: Dictionary, danger_level: int) -> Array:
    var features = []
    
    # Add type-specific features
    var type_features = planet_type.get("special_features", [])
    for feature in type_features:
        features.append(feature)
    
    # Add danger-specific features
    if danger_level >= 4:
        features.append("high_danger")
    if danger_level >= 6:
        features.append("extreme_danger")
    
    return features

## Discover a location on the world
func discover_location(world_data: Dictionary, location_index: int) -> Dictionary:
    if not world_data.has("locations"):
        return {}
    
    var locations = world_data.get("locations", [])
    if location_index < 0 or location_index >= locations.size():
        return {}
    
    var location = locations[location_index]
    location.explored = true
    
    # Add to visited locations list
    var visited = world_data.get("visited_locations", [])
    if not location.get("id") in visited:
        visited.append(location.get("id"))
    world_data.visited_locations = visited
    
    # Emit signal
    location_discovered.emit(location)
    
    return location

## Set the danger level modifier for world generation
func set_danger_level_modifier(modifier: int) -> void:
    _danger_level_modifier = modifier

## Set a specific planet type for the next generation
func set_specific_planet_type(planet_type: String, use_specific: bool = true) -> void:
    _specific_planet_type = planet_type
    _use_specific_planet_type = use_specific

## Get a list of all available planet types
func get_planet_types() -> Array:
    return _planet_types.duplicate()

## Get a list of all available location types
func get_location_types() -> Array:
    return _location_types.duplicate()

## Get a list of all available world traits
func get_world_traits() -> Array:
    return _world_traits.duplicate()