extends Node

signal sector_generated(sector_name: String)
signal planet_discovered(planet: GamePlanet)
signal sector_updated(sector_name: String)

const SECTOR_SIZE := Vector2(5, 5) # 5x5 grid of potential planet locations
const MIN_PLANETS_PER_SECTOR := 3
const MAX_PLANETS_PER_SECTOR := 7

var sectors: Dictionary = {} # sector_name: Array[GamePlanet]
var discovered_planets: Dictionary = {} # coordinates: GamePlanet
var current_sector: String = ""

# Planet name generation
const PlanetNameGenerator = preload("res://src/game/world/PlanetNameGenerator.gd")
var name_generator: PlanetNameGenerator

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const WorldManager = preload("res://src/game/world/GameWorldManager.gd")
const GamePlanet = preload("res://src/game/world/GamePlanet.gd")
const GameLocation = preload("res://src/game/world/GameLocation.gd")
const WorldDataMigration = preload("res://src/core/migration/WorldDataMigration.gd")

var migration: WorldDataMigration

func _init() -> void:
    name_generator = PlanetNameGenerator.new()
    migration = WorldDataMigration.new()

func generate_sector(sector_name: String) -> void:
    if sectors.has(sector_name):
        return
        
    var new_planets: Array[GamePlanet] = []
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

func _generate_planet(sector_name: String, coordinates: Vector2) -> GamePlanet:
    var planet = GamePlanet.new()
    planet.planet_name = name_generator.generate_name()
    planet.sector = sector_name
    planet.coordinates = coordinates
    
    # Randomly assign planet type and properties
    planet.planet_type = randi() % GameEnums.PlanetType.size()
    planet.faction_type = randi() % GameEnums.FactionType.size()
    planet.environment_type = randi() % GameEnums.PlanetEnvironment.size()
    
    # Generate world traits
    var world_trait_enum = randi() % GameEnums.WorldTrait.size()
    var trait_id = migration.convert_world_trait_to_id(world_trait_enum)
    if trait_id:
        planet.add_world_trait_by_id(trait_id)
    
    # Generate threats
    var threat = randi() % GameEnums.ThreatType.size()
    planet.add_threat(threat)
    
    planet.strife_level = randi() % GameEnums.StrifeType.size()
    planet.instability = randi() % GameEnums.StrifeType.size()
    
    planet_discovered.emit(planet)
    return planet

func get_planets_in_sector(sector_name: String) -> Array[GamePlanet]:
    return sectors.get(sector_name, [])

func get_planet_at_coordinates(coordinates: Vector2) -> GamePlanet:
    return discovered_planets.get(coordinates)

func update_sector(sector_name: String, current_turn: int) -> void:
    if not sectors.has(sector_name):
        return
        
    for planet in sectors[sector_name]:
        # GamePlanet doesn't have update_for_visit, but we can add custom logic here
        # or implement the method in GamePlanet if needed
        pass
    
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
        var planets: Array[GamePlanet] = []
        for planet_data in data.sectors[sector_name]:
            # Check if data needs migration
            if migration.needs_planet_migration(planet_data):
                planet_data = migration.migrate_planet_data(planet_data)
            
            var planet = GamePlanet.deserialize(planet_data)
            planets.append(planet)
            discovered_planets[planet.coordinates] = planet
        sectors[sector_name] = planets
    
    current_sector = data.get("current_sector", "")