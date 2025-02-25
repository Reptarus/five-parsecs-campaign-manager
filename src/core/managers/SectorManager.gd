extends Node

signal sector_generated(sector_name: String)
signal planet_discovered(planet: FiveParsecsPlanet)
signal sector_updated(sector_name: String)

const SECTOR_SIZE := Vector2(5, 5) # 5x5 grid of potential planet locations
const MIN_PLANETS_PER_SECTOR := 3
const MAX_PLANETS_PER_SECTOR := 7

var sectors: Dictionary = {} # sector_name: Array[FiveParsecsPlanet]
var discovered_planets: Dictionary = {} # coordinates: FiveParsecsPlanet
var current_sector: String = ""

# Planet name generation
const PlanetNameGenerator = preload("res://src/core/world/PlanetNameGenerator.gd")
var name_generator: PlanetNameGenerator

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const FiveParsecsLocation = preload("res://src/core/world/Location.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const WorldManager = preload("res://src/core/world/WorldManager.gd")
const FiveParsecsPlanet = preload("res://src/core/world/Planet.gd")

func _init() -> void:
    name_generator = PlanetNameGenerator.new()

func generate_sector(sector_name: String) -> void:
    if sectors.has(sector_name):
        return
        
    var new_planets: Array[FiveParsecsPlanet] = []
    var planet_count = randi_range(MIN_PLANETS_PER_SECTOR, MAX_PLANETS_PER_SECTOR)
    
    # Generate planet positions
    var positions = _generate_planet_positions(planet_count)
    
    # Create planets at each position
    for pos in positions:
        var planet = _generate_planet(sector_name, pos)
        new_planets.append(planet)
        discovered_planets[pos] = planet
    
    sectors[sector_name] = new_planets
    sector_generated.emit(sector_name)

func _generate_planet_positions(count: int) -> Array[Vector2]:
    var positions: Array[Vector2] = []
    var available_positions = []
    
    # Create grid of possible positions
    for x in range(SECTOR_SIZE.x):
        for y in range(SECTOR_SIZE.y):
            available_positions.append(Vector2(x, y))
    
    # Randomly select positions
    for i in range(count):
        if available_positions.is_empty():
            break
        var index = randi() % available_positions.size()
        positions.append(available_positions[index])
        available_positions.remove_at(index)
    
    return positions

func _generate_planet(sector_name: String, coordinates: Vector2) -> FiveParsecsPlanet:
    var planet = FiveParsecsPlanet.new()
    planet.planet_name = name_generator.generate_name()
    
    # Randomly assign planet type and properties
    planet.planet_type = randi() % GameEnums.PlanetType.size()
    planet.faction_type = randi() % GameEnums.FactionType.size()
    planet.environment_type = randi() % GameEnums.PlanetEnvironment.size()
    
    # Generate world traits and threats
    var world_trait = randi() % GameEnums.WorldTrait.size()
    planet.add_world_feature(world_trait)
    
    var threat = randi() % GameEnums.ThreatType.size()
    planet.add_threat(threat)
    
    planet.strife_level = randi() % GameEnums.StrifeType.size()
    planet.instability = randi() % GameEnums.StrifeType.size()
    
    planet_discovered.emit(planet)
    return planet

func get_planets_in_sector(sector_name: String) -> Array[FiveParsecsPlanet]:
    return sectors.get(sector_name, [])

func get_planet_at_coordinates(coordinates: Vector2) -> FiveParsecsPlanet:
    return discovered_planets.get(coordinates)

func update_sector(sector_name: String, current_turn: int) -> void:
    if not sectors.has(sector_name):
        return
        
    for planet in sectors[sector_name]:
        planet.update_for_visit(current_turn)
    
    sector_updated.emit(sector_name)

func serialize() -> Dictionary:
    var serialized_sectors = {}
    for sector_name in sectors:
        serialized_sectors[sector_name] = sectors[sector_name].map(func(p): return p.serialize())
    
    return {
        "sectors": serialized_sectors,
        "current_sector": current_sector
    }

func deserialize(data: Dictionary) -> void:
    sectors.clear()
    discovered_planets.clear()
    
    for sector_name in data.sectors:
        var planets: Array[FiveParsecsPlanet] = []
        for planet_data in data.sectors[sector_name]:
            var planet = FiveParsecsPlanet.deserialize(planet_data)
            planets.append(planet)
            discovered_planets[planet.coordinates] = planet
        sectors[sector_name] = planets
    
    current_sector = data.get("current_sector", "")