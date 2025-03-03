@tool
extends "res://tests/fixtures/base/game_test.gd"

const SectorManager: GDScript = preload("res://src/core/managers/SectorManager.gd")
const GamePlanet: GDScript = preload("res://src/game/world/GamePlanet.gd")
const WorldDataMigration: GDScript = preload("res://src/core/migration/WorldDataMigration.gd")

var sector_manager: Resource = null
var migration: Resource = null

func before_each() -> void:
    await super.before_each()
    sector_manager = SectorManager.new()
    if not sector_manager:
        push_error("Failed to create sector manager")
        return
    track_test_resource(sector_manager)
    
    # Create migration utility for testing
    migration = WorldDataMigration.new()
    track_test_resource(migration)
    
    await get_tree().process_frame

func test_initialization() -> void:
    var sectors: Array = _call_node_method(sector_manager, "get_sectors", [])
    assert_eq(sectors.size(), 0, "Should start with no sectors")

func test_sector_generation() -> void:
    var sector_count: int = 5
    _call_node_method_bool(sector_manager, "generate_sectors", [sector_count])
    var sectors: Array = _call_node_method(sector_manager, "get_sectors", [])
    assert_eq(sectors.size(), sector_count, "Should generate requested number of sectors")

func test_sector_connections() -> void:
    _call_node_method_bool(sector_manager, "generate_sectors", [3])
    var sectors: Array = _call_node_method(sector_manager, "get_sectors", [])
    for sector in sectors:
        var connections: Array = _call_node_method(sector, "get_connections", [])
        assert_gt(connections.size(), 0, "Each sector should have at least one connection")

func test_serialization() -> void:
    _call_node_method_bool(sector_manager, "generate_sectors", [3])
    var original_sectors: Array = _call_node_method(sector_manager, "get_sectors", [])
    var serialized: Dictionary = _call_node_method_dict(sector_manager, "serialize", [], {})
    var new_manager: Resource = SectorManager.new()
    track_test_resource(new_manager)
    _call_node_method_bool(new_manager, "deserialize", [serialized])
    var deserialized_sectors: Array = _call_node_method(new_manager, "get_sectors", [])
    assert_eq(deserialized_sectors.size(), original_sectors.size(), "Should maintain sector count after serialization")

func test_generate_sector() -> void:
    var sector_name = "test_sector"
    sector_manager.generate_sector(sector_name)
    
    # Test that the sector was created
    assert_true(sector_manager.sectors.has(sector_name), "Sector should be created")
    
    # Test that the correct number of planets were generated
    var planets = sector_manager.get_planets_in_sector(sector_name)
    assert_true(planets.size() >= sector_manager.MIN_PLANETS_PER_SECTOR, "Should have minimum number of planets")
    assert_true(planets.size() <= sector_manager.MAX_PLANETS_PER_SECTOR, "Should not exceed maximum number of planets")
    
    # Test that each planet is properly initialized
    for planet in planets:
        assert_not_null(planet, "Planet should not be null")
        assert_true(planet is GamePlanet, "Planet should be GamePlanet type")
        assert_not_null(planet.planet_name, "Planet should have a name")
        assert_true(planet.planet_type >= 0, "Planet should have valid planet type")
        assert_true(planet.faction_type >= 0, "Planet should have valid faction type")
        assert_true(planet.environment_type >= 0, "Planet should have valid environment type")
        
        # Test that the planet type is correctly converted
        var planet_type_id = migration.convert_planet_type_to_id(planet.planet_type)
        assert_not_null(planet_type_id, "Should convert planet type to ID")
        assert_ne(planet_type_id, "", "Planet type ID should not be empty")

func test_get_planet_at_coordinates() -> void:
    var sector_name = "test_sector"
    sector_manager.generate_sector(sector_name)
    
    # Get a planet from the discovered planets
    var coordinates = sector_manager.discovered_planets.keys()[0]
    var planet = sector_manager.get_planet_at_coordinates(coordinates)
    
    assert_not_null(planet, "Should return a planet at valid coordinates")
    assert_true(planet is GamePlanet, "Should return a GamePlanet instance")
    
    # Test that the planet type is correctly converted
    var planet_type_id = migration.convert_planet_type_to_id(planet.planet_type)
    assert_not_null(planet_type_id, "Should convert planet type to ID")
    assert_ne(planet_type_id, "", "Planet type ID should not be empty")

func test_sector_serialization() -> void:
    var sector_name = "test_sector"
    sector_manager.generate_sector(sector_name)
    
    # Serialize
    var data = sector_manager.serialize()
    assert_true(data.has("sectors"), "Serialized data should contain sectors")
    assert_true(data.has("current_sector"), "Serialized data should contain current_sector")
    
    # Create new manager and deserialize
    var new_manager = SectorManager.new()
    new_manager.deserialize(data)
    
    # Verify deserialized data
    assert_true(new_manager.sectors.has(sector_name), "Deserialized manager should have the sector")
    assert_eq(new_manager.sectors[sector_name].size(), sector_manager.sectors[sector_name].size(),
        "Deserialized sector should have same number of planets")

func test_migration_utility() -> void:
    var sector_name = "test_sector"
    sector_manager.generate_sector(sector_name)
    
    # Get a planet from the sector
    var planets = sector_manager.get_planets_in_sector(sector_name)
    assert_gt(planets.size(), 0, "Should have at least one planet")
    
    var planet = planets[0]
    assert_true(planet is GamePlanet, "Should be a GamePlanet instance")
    
    # Use the migration utility to convert to GamePlanet
    var game_planet = migration.migrate_planet(planet)
    assert_not_null(game_planet, "Migration should return a valid GamePlanet")
    assert_true(game_planet is GamePlanet, "Should return a GamePlanet instance")
    assert_eq(game_planet.planet_name, planet.planet_name, "GamePlanet should have same name")
    
    # Test that the planet type is correctly converted
    var planet_type_id = migration.convert_planet_type_to_id(planet.planet_type)
    assert_not_null(planet_type_id, "Should convert planet type to ID")
    assert_ne(planet_type_id, "", "Planet type ID should not be empty")
    
    # Test world trait conversion
    if planet.world_features.size() > 0:
        var trait_enum = planet.world_features[0]
        var trait_id = migration.convert_world_trait_to_id(trait_enum)
        assert_not_null(trait_id, "Should convert world trait to ID")
        assert_ne(trait_id, "", "World trait ID should not be empty")
        
        # Test that the GamePlanet has the trait
        assert_true(game_planet.has_trait(trait_id), "GamePlanet should have the trait")
    
    # Test two-way synchronization
    var new_name = "New Planet Name"
    game_planet.planet_name = new_name
    planet.update_from_game_planet()
    assert_eq(planet.planet_name, new_name, "GamePlanet should update from FiveParsecsPlanet")
    
    var newer_name = "Even Newer Planet Name"
    planet.planet_name = newer_name
    planet._sync_to_game_planet()
    assert_eq(game_planet.planet_name, newer_name, "FiveParsecsPlanet should update from GamePlanet")