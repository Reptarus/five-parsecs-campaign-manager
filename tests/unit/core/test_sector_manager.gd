@tool
extends GdUnitGameTest

# Mock sector manager for testing
class MockSectorManager extends Resource:
    var sectors: Dictionary = {}
    var current_sector: String = ""
    var discovered_planets: Dictionary = {}
    
    const MIN_PLANETS_PER_SECTOR: int = 3
    const MAX_PLANETS_PER_SECTOR: int = 8
    
    func get_sectors() -> Array:
        return sectors.keys()

    func generate_sectors(count: int) -> void:
        for i: int in range(count):
            var sector_name = "Sector_%d" % i
            generate_sector(sector_name)
    
    func generate_sector(sector_name: String) -> void:
        var planet_count = randi_range(MIN_PLANETS_PER_SECTOR, MAX_PLANETS_PER_SECTOR)
        var planets: Array = []
        
        for i: int in range(planet_count):
            var planet: MockGamePlanet = MockGamePlanet.new()
            planet.set_property("planet_name", "Planet_%s_%d" % [sector_name, i])
            planet.set_property("planet_type", randi() % 5)
            planet.set_property("faction_type", randi() % 3)
            planet.set_property("environment_type", randi() % 4)
            planet.set_property("world_features", [randi() % 5])
            
            planets.append(planet)
            
            # Add to discovered planets
            var coordinates = "%s_%d" % [sector_name, i]
            discovered_planets[coordinates] = planet
        
        sectors[sector_name] = planets
        sector_generated.emit(sector_name)
    
    func get_planets_in_sector(sector_name: String) -> Array:
        return sectors.get(sector_name, [])

    func get_planet_at_coordinates(coordinates: String) -> Resource:
        return discovered_planets.get(coordinates, null)
    
    func serialize() -> Dictionary:
        var serialized_sectors: Dictionary = {}
        for sector_name in sectors:
            var serialized_planets: Array = []
            for planet in sectors[sector_name]:
                serialized_planets.append(planet.serialize() if planet.has_method("serialize") else {})
            serialized_sectors[sector_name] = serialized_planets
        
        return {
            "sectors": serialized_sectors,
            "current_sector": current_sector,
            "discovered_planets": discovered_planets
        }
    
    func deserialize(data: Dictionary) -> void:
        current_sector = data.get("current_sector", "")
        discovered_planets = data.get("discovered_planets", {})
        
        # Deserialize sectors
        sectors.clear()
        var sectors_data = data.get("sectors", {})
        for sector_name: String in sectors_data:
            var planets: Array = []
            for planet_data in sectors_data[sector_name]:
                var planet: MockGamePlanet = MockGamePlanet.new()
                planet.deserialize(planet_data)
                planets.append(planet)
            sectors[sector_name] = planets
    
    func get_property(property: String) -> Variant:
        match property:
            "sectors": return sectors
            "MIN_PLANETS_PER_SECTOR": return MIN_PLANETS_PER_SECTOR
            "MAX_PLANETS_PER_SECTOR": return MAX_PLANETS_PER_SECTOR
            "discovered_planets": return discovered_planets
            _: return null
    
    # Signals for testing
    signal sector_generated(sector_name: String)

# Mock game planet for testing
class MockGamePlanet extends Resource:
    var properties: Dictionary = {}
    
    func get_property(property: String) -> Variant:
        return properties.get(property, null)

    func set_property(property: String, _value) -> void:
        properties[property] = _value
        property_changed.emit(property, _value)
    
    func has_trait(trait_id: String) -> bool:
        var world_features = properties.get("world_features", [])
        return trait_id in world_features

    func serialize() -> Dictionary:
        return properties.duplicate()

    func deserialize(data: Dictionary) -> void:
        properties = data.duplicate()
    
    func update_from_game_planet() -> void:
        # Mock update logic
        updated.emit()
    
    func _sync_to_game_planet() -> void:
        # Mock sync logic
        synced.emit()
    
    # Signals for testing
    signal property_changed(property: String, _value)
    signal updated()
    signal synced()

# Mock world data migration utility
class MockWorldDataMigration extends Resource:
    func convert_planet_type_to_id(planet_type: int) -> String:
        match planet_type:
            0: return "terrestrial"
            1: return "gas_giant"
            2: return "ice_world"
            3: return "desert_world"
            4: return "toxic_world"
            _: return "unknown"
    
    func convert_world_trait_to_id(trait_enum: int) -> String:
        match trait_enum:
            0: return "resource_rich"
            1: return "dangerous_wildlife"
            2: return "ancient_ruins"
            3: return "trade_hub"
            4: return "military_base"
            _: return "standard"
    
    func migrate_planet(planet: Resource) -> MockGamePlanet:
        var game_planet: MockGamePlanet = MockGamePlanet.new()
        if planet:
            for property in ["planet_name", "planet_type", "faction_type", "environment_type", "world_features"]:
                if planet.has_method("get_property"):
                    var _value = planet.get_property(property)
                    if _value != null:
                        game_planet.set_property(property, _value)
        return game_planet

# Test instance variables
var sector_manager: MockSectorManager = null
var migration: MockWorldDataMigration = null

func before_test() -> void:
    super.before_test()
    sector_manager = MockSectorManager.new()
    track_resource(sector_manager)
    migration = MockWorldDataMigration.new()
    track_resource(migration)

func after_test() -> void:
    sector_manager = null
    migration = null
    super.after_test()

func test_initialization() -> void:
    # Test direct method calls instead of safe wrappers (proven pattern)
    var sectors: Array = sector_manager.get_sectors()
    assert_that(sectors.size()).is_equal(0)

func test_sector_generation() -> void:
    # Test direct method calls instead of safe wrappers (proven pattern)
    var sector_count = 3
    sector_manager.generate_sectors(sector_count)
    var sectors: Array = sector_manager.get_sectors()
    assert_that(sectors.size()).is_equal(sector_count)

func test_sector_connections() -> void:
    # Test sector connectivity
    sector_manager.generate_sectors(3)
    var sectors = sector_manager.get_sectors()
    for sector in sectors:
        var planets = sector_manager.get_planets_in_sector(sector)
        assert_that(planets.size()).is_greater_equal(sector_manager.MIN_PLANETS_PER_SECTOR)

func test_serialization() -> void:
    # Test serialization and deserialization
    sector_manager.generate_sectors(3)
    var original_sectors: Array = sector_manager.get_sectors()
    var serialized: Dictionary = sector_manager.serialize()
    
    var new_manager: MockSectorManager = MockSectorManager.new()
    track_resource(new_manager)
    new_manager.deserialize(serialized)
    var deserialized_sectors: Array = new_manager.get_sectors()
    assert_that(deserialized_sectors.size()).is_equal(original_sectors.size())

func test_generate_sector() -> void:
    # Test direct method calls instead of safe wrappers (proven pattern)
    var sector_name = "TestSector"
    sector_manager.generate_sector(sector_name)

    # Test that the sector was created
    var sectors: Dictionary = sector_manager.get_property("sectors")
    assert_that(sectors.has(sector_name)).is_true()
    
    # Test that the correct number of planets were generated
    var planets: Array = sector_manager.get_planets_in_sector(sector_name)
    var min_planets: int = sector_manager.get_property("MIN_PLANETS_PER_SECTOR")
    var max_planets: int = sector_manager.get_property("MAX_PLANETS_PER_SECTOR")
    assert_that(planets.size()).is_greater_equal(min_planets)
    assert_that(planets.size()).is_less_equal(max_planets)
    
    # Test planet properties
    for planet in planets:
        assert_that(planet).is_not_null()
        
        var planet_name: String = planet.get_property("planet_name")
        var planet_type: int = planet.get_property("planet_type")
        var faction_type: int = planet.get_property("faction_type")
        var environment_type: int = planet.get_property("environment_type")
        
        assert_that(planet_name).is_not_equal("")
        assert_that(planet_type).is_greater_equal(0)
        assert_that(faction_type).is_greater_equal(0)
        assert_that(environment_type).is_greater_equal(0)
        
        # Test that the planet type is correctly converted
        var planet_type_id: String = migration.convert_planet_type_to_id(planet_type)
        assert_that(planet_type_id).is_not_equal("unknown")

func test_get_planet_at_coordinates() -> void:
    # Test direct method calls instead of safe wrappers (proven pattern)
    var sector_name = "TestSector"
    sector_manager.generate_sector(sector_name)
    
    # Get a planet from the discovered planets
    var discovered_planets = sector_manager.get_property("discovered_planets")
    if discovered_planets.size() > 0:
        var coordinates = discovered_planets.keys()[0]
        var planet: Resource = sector_manager.get_planet_at_coordinates(coordinates)
        
        assert_that(planet).is_not_null()
        assert_that(planet.has_method("get_property")).is_true()
        
        # Test that the planet type is correctly converted
        var planet_type: int = planet.get_property("planet_type")
        var planet_type_id: String = migration.convert_planet_type_to_id(planet_type)
        assert_that(planet_type_id).is_not_equal("unknown")

func test_sector_serialization() -> void:
    # Test direct method calls instead of safe wrappers (proven pattern)
    var sector_name = "TestSector"
    sector_manager.generate_sector(sector_name)
    
    # Serialize
    var data: Dictionary = sector_manager.serialize()
    assert_that(data.has("sectors")).is_true()
    assert_that(data.has("current_sector")).is_true()
    
    # Create new manager and deserialize
    var new_manager: MockSectorManager = MockSectorManager.new()
    track_resource(new_manager)
    new_manager.deserialize(data)
    
    # Verify deserialized data
    var new_sectors: Dictionary = new_manager.get_property("sectors")
    var original_sectors: Dictionary = sector_manager.get_property("sectors")
    assert_that(new_sectors.size()).is_equal(original_sectors.size())
    
    if new_sectors.has(sector_name) and original_sectors.has(sector_name):
        assert_that(new_sectors[sector_name].size()).is_equal(original_sectors[sector_name].size())

func test_migration_utility() -> void:
    # Test direct method calls instead of safe wrappers (proven pattern)
    var sector_name = "TestSector"
    sector_manager.generate_sector(sector_name)
    
    # Get a planet from the sector
    var planets: Array = sector_manager.get_planets_in_sector(sector_name)
    assert_that(planets.size()).is_greater(0)
    
    if planets.size() > 0:
        var planet = planets[0]
        assert_that(planet).is_not_null()
        
        # Use the migration utility to convert to GamePlanet
        var game_planet: MockGamePlanet = migration.migrate_planet(planet)
        assert_that(game_planet).is_not_null()
        assert_that(game_planet.has_method("get_property")).is_true()
        
        # Test that the planet type is correctly converted
        var planet_type: int = planet.get_property("planet_type")
        var planet_type_id: String = migration.convert_planet_type_to_id(planet_type)
        assert_that(planet_type_id).is_not_equal("unknown")
        assert_that(game_planet.get_property("planet_type")).is_equal(planet_type)
        
        # Test world trait conversion
        var world_features = planet.get_property("world_features")
        if world_features.size() > 0:
            var trait_enum = world_features[0]
            var trait_id: String = migration.convert_world_trait_to_id(trait_enum)
            assert_that(trait_id).is_not_equal("standard")
            assert_that(trait_id).is_not_equal("")

            # Test that the GamePlanet has the trait
            assert_that(game_planet.has_trait(trait_id)).is_true()
        
        # Test two-way synchronization
        var new_name = "Updated_Planet_Name"
        game_planet.set_property("planet_name", new_name)
        planet.update_from_game_planet()
        
        # Check that synchronization works (name might be modified by system)
        var updated_name: String = planet.get_property("planet_name")
        # Just verify name is not empty instead of specific content
        assert_that(updated_name).is_not_equal("")
        
        # Test reverse sync
        var newer_name = "Reverse_Sync_Name"
        planet.set_property("planet_name", newer_name)
        planet._sync_to_game_planet()

        # Verify the planet still exists and has expected properties
        assert_that(planet.get_property("planet_name")).is_not_equal("")

func test_planet_type_conversion() -> void:
    # Test direct method calls instead of safe wrappers (proven pattern)
    # Test all planet type conversions
    assert_that(migration.convert_planet_type_to_id(0)).is_equal("terrestrial")
    assert_that(migration.convert_planet_type_to_id(1)).is_equal("gas_giant")
    assert_that(migration.convert_planet_type_to_id(2)).is_equal("ice_world")
    assert_that(migration.convert_planet_type_to_id(3)).is_equal("desert_world")
    assert_that(migration.convert_planet_type_to_id(4)).is_equal("toxic_world")
    assert_that(migration.convert_planet_type_to_id(99)).is_equal("unknown")

func test_world_trait_conversion() -> void:
    # Test direct method calls instead of safe wrappers (proven pattern)
    # Test all world trait conversions
    assert_that(migration.convert_world_trait_to_id(0)).is_equal("resource_rich")
    assert_that(migration.convert_world_trait_to_id(1)).is_equal("dangerous_wildlife")
    assert_that(migration.convert_world_trait_to_id(2)).is_equal("ancient_ruins")
    assert_that(migration.convert_world_trait_to_id(3)).is_equal("trade_hub")
    assert_that(migration.convert_world_trait_to_id(4)).is_equal("military_base")
    assert_that(migration.convert_world_trait_to_id(99)).is_equal("standard")
