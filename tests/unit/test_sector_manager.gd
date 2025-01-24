extends "res://addons/gut/test.gd"

var sector_manager: SectorManager

func before_each() -> void:
    sector_manager = SectorManager.new()
    add_child(sector_manager)

func after_each() -> void:
    sector_manager.queue_free()
    sector_manager = null

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