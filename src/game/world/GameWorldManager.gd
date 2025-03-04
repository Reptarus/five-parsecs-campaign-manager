@tool
class_name GameWorldManager
extends Node

## Manager class for world generation and management

# Import required classes
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameDataManager = preload("res://src/core/managers/GameDataManager.gd")
const GamePlanet = preload("res://src/game/world/GamePlanet.gd")
const GameLocation = preload("res://src/game/world/GameLocation.gd")
const GameWorldTrait = preload("res://src/game/world/GameWorldTrait.gd")

# Signals
signal world_generated
signal world_region_discovered(region_id: String)
signal location_updated(location)
signal planet_discovered(planet)
signal planet_updated(planet)

# World generation parameters
@export var sector_size: Vector2i = Vector2i(5, 5)
@export var min_planets_per_sector: int = 3
@export var max_planets_per_sector: int = 7
@export var min_locations_per_planet: int = 2
@export var max_locations_per_planet: int = 5
@export var connection_density: float = 0.3

# World data
var planets: Dictionary = {} # planet_id: GamePlanet
var current_planet_id: String = ""
var current_location_id: String = ""
var sectors: Dictionary = {} # sector_name: {coordinates: Vector2, planets: Array}

# Data manager for loading traits
var _data_manager: GameDataManager = null

func _init() -> void:
    # Create the data manager instance
    if not Engine.is_editor_hint():
        _data_manager = GameDataManager.new()
        _data_manager.load_all_data()

## Generate a new game world with the specified number of sectors
func generate_world(num_sectors: int = 1) -> void:
    # Clear existing world data
    planets.clear()
    sectors.clear()
    
    # Generate sectors
    for i in range(num_sectors):
        var sector_name = "Sector " + str(i + 1)
        _generate_sector(sector_name, Vector2(i * sector_size.x, 0))
    
    # Connect planets between sectors
    _connect_sectors()
    
    emit_signal("world_generated")

## Generate a single sector with planets
func _generate_sector(sector_name: String, sector_position: Vector2) -> void:
    var sector_data = {
        "name": sector_name,
        "coordinates": sector_position,
        "planets": []
    }
    
    # Determine number of planets in this sector
    var num_planets = randi_range(min_planets_per_sector, max_planets_per_sector)
    
    # Generate planets
    for i in range(num_planets):
        var planet = _generate_planet(sector_name, sector_position)
        sector_data.planets.append(planet.planet_id)
        planets[planet.planet_id] = planet
    
    # Connect planets within the sector
    _connect_planets_in_sector(sector_data.planets)
    
    # Store sector data
    sectors[sector_name] = sector_data

## Generate a single planet with locations
func _generate_planet(sector_name: String, sector_position: Vector2) -> GamePlanet:
    var planet = GamePlanet.new()
    
    # Generate unique ID
    planet.planet_id = "planet_" + str(randi())
    
    # Set basic properties
    planet.planet_name = _generate_planet_name()
    planet.sector = sector_name
    
    # Random position within sector
    var x_offset = randf_range(0, sector_size.x)
    var y_offset = randf_range(0, sector_size.y)
    planet.coordinates = sector_position + Vector2(x_offset, y_offset)
    
    # Random planet type
    planet.planet_type = randi() % GameEnums.PlanetType.size()
    if planet.planet_type == GameEnums.PlanetType.NONE:
        planet.planet_type = GameEnums.PlanetType.TEMPERATE
    
    # Generate description
    planet.description = _generate_planet_description(planet.planet_type)
    
    # Random faction control
    planet.faction_type = randi() % GameEnums.FactionType.size()
    if planet.faction_type == GameEnums.FactionType.NONE:
        planet.faction_type = GameEnums.FactionType.NEUTRAL
    
    # Random environment
    planet.environment_type = randi() % GameEnums.PlanetEnvironment.size()
    if planet.environment_type == GameEnums.PlanetEnvironment.NONE:
        planet.environment_type = GameEnums.PlanetEnvironment.URBAN
    
    # Add world traits based on planet type
    _add_traits_based_on_planet_type(planet)
    
    # Generate locations
    var num_locations = randi_range(min_locations_per_planet, max_locations_per_planet)
    for i in range(num_locations):
        var location = _generate_location(planet)
        planet.add_location(location)
    
    # Connect locations
    _connect_locations_on_planet(planet)
    
    return planet

## Generate a location for a planet
func _generate_location(planet: GamePlanet) -> GameLocation:
    var location = GameLocation.new()
    
    # Generate unique ID
    location.location_id = "loc_" + str(randi())
    
    # Set basic properties
    location.location_name = _generate_location_name(planet.planet_type)
    
    # Random location type
    location.location_type = randi() % GameEnums.LocationType.size()
    if location.location_type == GameEnums.LocationType.NONE:
        location.location_type = GameEnums.LocationType.INDUSTRIAL_HUB
    
    # Generate description
    location.description = _generate_location_description(location.location_type)
    
    # Random position relative to planet
    var angle = randf_range(0, TAU)
    var distance = randf_range(0.1, 0.5)
    location.coordinates = planet.coordinates + Vector2(cos(angle), sin(angle)) * distance
    
    # Random danger level
    location.danger_level = randi_range(1, 5)
    
    # Random faction control (usually matches planet)
    if randf() < 0.8:
        location.faction_control = planet.faction_type
    else:
        location.faction_control = randi() % GameEnums.FactionType.size()
        if location.faction_control == GameEnums.FactionType.NONE:
            location.faction_control = GameEnums.FactionType.NEUTRAL
    
    # Add world traits based on location type
    _add_traits_based_on_location_type(location)
    
    # Initialize resources based on location type
    _initialize_location_resources(location)
    
    return location

## Connect planets within a sector
func _connect_planets_in_sector(planet_ids: Array) -> void:
    # Ensure all planets are connected in a minimum spanning tree
    var connected_planets = [planet_ids[0]]
    var unconnected_planets = planet_ids.slice(1)
    
    while not unconnected_planets.is_empty():
        var closest_distance = INF
        var closest_connected = ""
        var closest_unconnected = ""
        
        for connected_id in connected_planets:
            var connected_planet = planets[connected_id]
            
            for unconnected_id in unconnected_planets:
                var unconnected_planet = planets[unconnected_id]
                var distance = connected_planet.coordinates.distance_to(unconnected_planet.coordinates)
                
                if distance < closest_distance:
                    closest_distance = distance
                    closest_connected = connected_id
                    closest_unconnected = unconnected_id
        
        # Add connection
        # In a real implementation, you would store these connections somewhere
        
        # Move planet to connected list
        connected_planets.append(closest_unconnected)
        unconnected_planets.erase(closest_unconnected)
    
    # Add some additional connections based on connection_density
    var num_additional_connections = int(planet_ids.size() * connection_density)
    for i in range(num_additional_connections):
        var planet1_idx = randi() % planet_ids.size()
        var planet2_idx = randi() % planet_ids.size()
        
        # Ensure we're not connecting a planet to itself
        if planet1_idx != planet2_idx:
            # Add connection
            # In a real implementation, you would store these connections somewhere
            pass

## Connect locations on a planet
func _connect_locations_on_planet(planet: GamePlanet) -> void:
    var location_ids = []
    for location in planet.locations:
        location_ids.append(location.location_id)
    
    # Ensure all locations are connected in a minimum spanning tree
    if location_ids.size() <= 1:
        return
        
    var connected_locations = [location_ids[0]]
    var unconnected_locations = location_ids.slice(1)
    
    while not unconnected_locations.is_empty():
        var closest_distance = INF
        var closest_connected = ""
        var closest_unconnected = ""
        
        for connected_id in connected_locations:
            var connected_location = planet.get_location_by_id(connected_id)
            
            for unconnected_id in unconnected_locations:
                var unconnected_location = planet.get_location_by_id(unconnected_id)
                var distance = connected_location.coordinates.distance_to(unconnected_location.coordinates)
                
                if distance < closest_distance:
                    closest_distance = distance
                    closest_connected = connected_id
                    closest_unconnected = unconnected_id
        
        # Add connection
        var connected_location = planet.get_location_by_id(closest_connected)
        var unconnected_location = planet.get_location_by_id(closest_unconnected)
        
        connected_location.add_connected_location(closest_unconnected)
        unconnected_location.add_connected_location(closest_connected)
        
        # Move location to connected list
        connected_locations.append(closest_unconnected)
        unconnected_locations.erase(closest_unconnected)
    
    # Add some additional connections based on connection_density
    var num_additional_connections = int(location_ids.size() * connection_density)
    for i in range(num_additional_connections):
        var loc1_idx = randi() % location_ids.size()
        var loc2_idx = randi() % location_ids.size()
        
        # Ensure we're not connecting a location to itself
        if loc1_idx != loc2_idx:
            var loc1_id = location_ids[loc1_idx]
            var loc2_id = location_ids[loc2_idx]
            
            var loc1 = planet.get_location_by_id(loc1_id)
            var loc2 = planet.get_location_by_id(loc2_id)
            
            # Add connection if it doesn't already exist
            if not loc1.is_connected_to(loc2_id):
                loc1.add_connected_location(loc2_id)
                loc2.add_connected_location(loc1_id)

## Connect sectors together
func _connect_sectors() -> void:
    # This would connect planets between different sectors
    # For simplicity, we'll just connect the closest planets between adjacent sectors
    var sector_names = sectors.keys()
    if sector_names.size() <= 1:
        return
    
    for i in range(sector_names.size() - 1):
        var sector1 = sectors[sector_names[i]]
        var sector2 = sectors[sector_names[i + 1]]
        
        # Find closest planets between these sectors
        var closest_distance = INF
        var closest_planet1 = ""
        var closest_planet2 = ""
        
        for planet1_id in sector1.planets:
            var planet1 = planets[planet1_id]
            
            for planet2_id in sector2.planets:
                var planet2 = planets[planet2_id]
                var distance = planet1.coordinates.distance_to(planet2.coordinates)
                
                if distance < closest_distance:
                    closest_distance = distance
                    closest_planet1 = planet1_id
                    closest_planet2 = planet2_id
        
        # Add connection
        # In a real implementation, you would store these connections somewhere
        pass

## Add world traits to a planet based on its type
func _add_traits_based_on_planet_type(planet: GamePlanet) -> void:
    var trait_id = ""
    
    match planet.planet_type:
        GameEnums.PlanetType.DESERT:
            trait_id = "desert_world"
        GameEnums.PlanetType.ICE:
            trait_id = "ice_world"
        GameEnums.PlanetType.JUNGLE:
            trait_id = "jungle_world"
        GameEnums.PlanetType.TEMPERATE:
            trait_id = "frontier_world"
        GameEnums.PlanetType.ROCKY:
            trait_id = "mining_world"
        GameEnums.PlanetType.VOLCANIC:
            trait_id = "mining_world"
        _:
            trait_id = "frontier_world"
    
    planet.add_world_trait_by_id(trait_id)
    
    # Add a random second trait with 30% chance
    if randf() < 0.3:
        var second_trait = ""
        var traits = ["urban_world", "mining_world", "frontier_world"]
        
        # Remove the trait we already added
        if trait_id in traits:
            traits.erase(trait_id)
        
        if not traits.is_empty():
            second_trait = traits[randi() % traits.size()]
            planet.add_world_trait_by_id(second_trait)

## Add world traits to a location based on its type
func _add_traits_based_on_location_type(location: GameLocation) -> void:
    var trait_id = ""
    
    match location.location_type:
        GameEnums.LocationType.INDUSTRIAL_HUB:
            trait_id = "urban_world"
        GameEnums.LocationType.FRONTIER_WORLD:
            trait_id = "frontier_world"
        GameEnums.LocationType.TRADE_CENTER:
            trait_id = "urban_world"
        GameEnums.LocationType.MINING_COLONY:
            trait_id = "mining_world"
        _:
            trait_id = "frontier_world"
    
    location.add_world_trait_by_id(trait_id)

## Initialize resources for a location based on its type
func _initialize_location_resources(location: GameLocation) -> void:
    # Base resources
    location.resources[GameLocation.RESOURCE_CREDITS] = randi_range(100, 500)
    location.resources[GameLocation.RESOURCE_SUPPLIES] = randi_range(10, 50)
    location.resources[GameLocation.RESOURCE_FUEL] = randi_range(20, 100)
    
    # Type-specific resources
    match location.location_type:
        GameEnums.LocationType.INDUSTRIAL_HUB:
            location.resources[GameLocation.RESOURCE_TECHNOLOGY] = randi_range(30, 80)
            location.resources[GameLocation.RESOURCE_WEAPONS] = randi_range(20, 60)
        GameEnums.LocationType.FRONTIER_WORLD:
            location.resources[GameLocation.RESOURCE_SUPPLIES] += randi_range(30, 80)
            location.resources[GameLocation.RESOURCE_FUEL] += randi_range(10, 40)
        GameEnums.LocationType.TRADE_CENTER:
            location.resources[GameLocation.RESOURCE_LUXURY_GOODS] = randi_range(40, 100)
            location.resources[GameLocation.RESOURCE_CREDITS] += randi_range(200, 800)
        GameEnums.LocationType.MINING_COLONY:
            location.resources[GameLocation.RESOURCE_MINERALS] = randi_range(50, 120)
            location.resources[GameLocation.RESOURCE_RARE_MATERIALS] = randi_range(10, 30)
        GameEnums.LocationType.PIRATE_HAVEN:
            location.resources[GameLocation.RESOURCE_WEAPONS] = randi_range(30, 90)
            location.black_market_active = true
        GameEnums.LocationType.TECH_CENTER:
            location.resources[GameLocation.RESOURCE_TECHNOLOGY] = randi_range(50, 150)
            location.resources[GameLocation.RESOURCE_MEDICAL_SUPPLIES] = randi_range(30, 80)

## Generate a random planet name
func _generate_planet_name() -> String:
    var prefixes = ["New", "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Omega", "Prime", "Nova"]
    var roots = ["Terra", "Gaia", "Ares", "Helios", "Kronos", "Atlas", "Hyperion", "Prometheus", "Oceanus"]
    var suffixes = ["I", "II", "III", "IV", "V", "Prime", "Major", "Minor", "Alpha", "Beta"]
    
    var name = ""
    
    # 30% chance to have a prefix
    if randf() < 0.3:
        name += prefixes[randi() % prefixes.size()] + " "
    
    # Always have a root name
    name += roots[randi() % roots.size()]
    
    # 40% chance to have a suffix
    if randf() < 0.4:
        name += " " + suffixes[randi() % suffixes.size()]
    
    return name

## Generate a random location name
func _generate_location_name(planet_type: int) -> String:
    var prefixes = ["Port", "Fort", "Mount", "New", "Old", "Lower", "Upper", "Central", "North", "South", "East", "West"]
    var roots = ["Haven", "Hope", "Prosperity", "Liberty", "Freedom", "Unity", "Harmony", "Serenity", "Refuge", "Sanctuary"]
    var type_specific = {
        GameEnums.PlanetType.DESERT: ["Dune", "Oasis", "Mirage", "Dust", "Sand"],
        GameEnums.PlanetType.ICE: ["Frost", "Glacier", "Tundra", "Snowfield", "Iceberg"],
        GameEnums.PlanetType.JUNGLE: ["Grove", "Thicket", "Canopy", "Verdant", "Emerald"],
        GameEnums.PlanetType.TEMPERATE: ["Meadow", "Valley", "Hill", "Dale", "Field"],
        GameEnums.PlanetType.ROCKY: ["Ridge", "Peak", "Crag", "Stone", "Boulder"],
        GameEnums.PlanetType.VOLCANIC: ["Ember", "Ash", "Cinder", "Magma", "Forge"]
    }
    
    var name = ""
    
    # 50% chance to have a prefix
    if randf() < 0.5:
        name += prefixes[randi() % prefixes.size()] + " "
    
    # Choose root name
    if planet_type in type_specific and randf() < 0.6:
        var type_roots = type_specific[planet_type]
        name += type_roots[randi() % type_roots.size()]
    else:
        name += roots[randi() % roots.size()]
    
    return name

## Generate a planet description based on its type
func _generate_planet_description(planet_type: int) -> String:
    var descriptions = {
        GameEnums.PlanetType.DESERT: "A harsh, arid world with vast deserts and scarce water resources.",
        GameEnums.PlanetType.ICE: "A frozen wasteland with temperatures well below freezing most of the year.",
        GameEnums.PlanetType.JUNGLE: "A lush, overgrown world with dense vegetation and diverse wildlife.",
        GameEnums.PlanetType.TEMPERATE: "A world with moderate climate and varied ecosystems, suitable for human habitation.",
        GameEnums.PlanetType.ROCKY: "A rugged world with mountainous terrain and valuable mineral deposits.",
        GameEnums.PlanetType.VOLCANIC: "An unstable world with active volcanoes and geothermal activity.",
        GameEnums.PlanetType.OCEAN: "A world covered mostly by vast oceans with scattered island chains."
    }
    
    if planet_type in descriptions:
        return descriptions[planet_type]
    else:
        return "A mysterious world with unknown characteristics."

## Generate a location description based on its type
func _generate_location_description(location_type: int) -> String:
    var descriptions = {
        GameEnums.LocationType.INDUSTRIAL_HUB: "A bustling center of manufacturing and production.",
        GameEnums.LocationType.FRONTIER_WORLD: "A remote outpost on the edge of settled space.",
        GameEnums.LocationType.TRADE_CENTER: "A busy marketplace where goods from across the sector change hands.",
        GameEnums.LocationType.PIRATE_HAVEN: "A lawless den of smugglers and outlaws.",
        GameEnums.LocationType.FREE_PORT: "An independent trading post free from faction control.",
        GameEnums.LocationType.CORPORATE_CONTROLLED: "A settlement under the strict control of a powerful corporation.",
        GameEnums.LocationType.TECH_CENTER: "A hub of research and technological innovation.",
        GameEnums.LocationType.MINING_COLONY: "A rugged settlement focused on extracting valuable resources.",
        GameEnums.LocationType.AGRICULTURAL_WORLD: "A peaceful community dedicated to food production."
    }
    
    if location_type in descriptions:
        return descriptions[location_type]
    else:
        return "A settlement with various facilities and services."

## Get a planet by ID
func get_planet(planet_id: String) -> GamePlanet:
    if planets.has(planet_id):
        return planets[planet_id]
    return null

## Get the current planet
func get_current_planet() -> GamePlanet:
    return get_planet(current_planet_id)

## Get a location on the current planet by ID
func get_location(location_id: String) -> GameLocation:
    var planet = get_current_planet()
    if planet:
        return planet.get_location_by_id(location_id)
    return null

## Get the current location
func get_current_location() -> GameLocation:
    return get_location(current_location_id)

## Set the current planet
func set_current_planet(planet_id: String) -> void:
    if planets.has(planet_id):
        current_planet_id = planet_id
        
        # Mark planet as visited
        var planet = planets[planet_id]
        if not planet.visited:
            planet.visited = true
            emit_signal("planet_updated", planet)

## Set the current location
func set_current_location(location_id: String) -> void:
    var planet = get_current_planet()
    if planet:
        var location = planet.get_location_by_id(location_id)
        if location:
            current_location_id = location_id
            
            # Mark location as visited
            if not location.visited:
                location.visited = true
                emit_signal("location_updated", location)

## Serialize all world data
func serialize() -> Dictionary:
    var planet_data = {}
    for planet_id in planets:
        planet_data[planet_id] = planets[planet_id].serialize()
    
    var sector_data = {}
    for sector_name in sectors:
        sector_data[sector_name] = sectors[sector_name]
    
    return {
        "planets": planet_data,
        "sectors": sector_data,
        "current_planet_id": current_planet_id,
        "current_location_id": current_location_id
    }

## Deserialize world data
func deserialize(data: Dictionary) -> void:
    planets.clear()
    sectors.clear()
    
    # Load planets
    var planet_data = data.get("planets", {})
    for planet_id in planet_data:
        planets[planet_id] = GamePlanet.deserialize(planet_data[planet_id])
    
    # Load sectors
    sectors = data.get("sectors", {})
    
    # Set current planet and location
    current_planet_id = data.get("current_planet_id", "")
    current_location_id = data.get("current_location_id", "")