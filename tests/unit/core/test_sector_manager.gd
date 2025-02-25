@tool
extends "res://tests/fixtures/game_test.gd"

const SectorManager: GDScript = preload("res://src/core/managers/SectorManager.gd")

var sector_manager: Resource = null

func before_each() -> void:
    await super.before_each()
    sector_manager = SectorManager.new()
    if not sector_manager:
        push_error("Failed to create sector manager")
        return
    track_test_resource(sector_manager)
    await get_tree().process_frame

func test_initialization() -> void:
    var sectors: Array = TypeSafeMixin._safe_method_call_array(sector_manager, "get_sectors", [], [])
    assert_eq(sectors.size(), 0, "Should start with no sectors")

func test_sector_generation() -> void:
    var sector_count: int = 5
    TypeSafeMixin._safe_method_call_void(sector_manager, "generate_sectors", [sector_count])
    var sectors: Array = TypeSafeMixin._safe_method_call_array(sector_manager, "get_sectors", [], [])
    assert_eq(sectors.size(), sector_count, "Should generate requested number of sectors")

func test_sector_connections() -> void:
    TypeSafeMixin._safe_method_call_void(sector_manager, "generate_sectors", [3])
    var sectors: Array = TypeSafeMixin._safe_method_call_array(sector_manager, "get_sectors", [], [])
    for sector in sectors:
        var connections: Array = TypeSafeMixin._safe_method_call_array(sector, "get_connections", [], [])
        assert_gt(connections.size(), 0, "Each sector should have at least one connection")

func test_serialization() -> void:
    TypeSafeMixin._safe_method_call_void(sector_manager, "generate_sectors", [3])
    var original_sectors: Array = TypeSafeMixin._safe_method_call_array(sector_manager, "get_sectors", [], [])
    var serialized: Dictionary = TypeSafeMixin._safe_method_call_dictionary(sector_manager, "serialize", [], {})
    var new_manager: Resource = SectorManager.new()
    track_test_resource(new_manager)
    TypeSafeMixin._safe_method_call_void(new_manager, "deserialize", [serialized])
    var deserialized_sectors: Array = TypeSafeMixin._safe_method_call_array(new_manager, "get_sectors", [], [])
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
        assert_true(planet is FiveParsecsPlanet, "Planet should be FiveParsecsPlanet type")
        assert_not_null(planet.planet_name, "Planet should have a name")
        assert_true(planet.planet_type >= 0, "Planet should have valid planet type")
        assert_true(planet.faction_type >= 0, "Planet should have valid faction type")
        assert_true(planet.environment_type >= 0, "Planet should have valid environment type")

func test_get_planet_at_coordinates() -> void:
    var sector_name = "test_sector"
    sector_manager.generate_sector(sector_name)
    
    # Get a planet from the discovered planets
    var coordinates = sector_manager.discovered_planets.keys()[0]
    var planet = sector_manager.get_planet_at_coordinates(coordinates)
    
    assert_not_null(planet, "Should return a planet at valid coordinates")
    assert_true(planet is FiveParsecsPlanet, "Should return a FiveParsecsPlanet instance")

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