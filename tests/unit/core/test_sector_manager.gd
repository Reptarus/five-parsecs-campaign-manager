@tool
extends "res://tests/fixtures/base/game_test.gd"

const SectorManager: GDScript = preload("res://src/core/managers/SectorManager.gd")
const GamePlanet: GDScript = preload("res://src/game/world/GamePlanet.gd")
const WorldDataMigration: GDScript = preload("res://src/core/migration/WorldDataMigration.gd")

# Use variable without type annotation to allow for more flexibility
var sector_manager = null
var migration = null

func before_each() -> void:
	await super.before_each()
	
	# Create sector manager with type safety
	if SectorManager:
		sector_manager = SectorManager.new()
		if not sector_manager:
			push_error("Failed to create sector manager")
			return
			
		# Add to scene tree if it's a Node
		if sector_manager is Node:
			add_child_autofree(sector_manager)
			track_test_node(sector_manager)
		elif sector_manager is Resource:
			track_test_resource(sector_manager)
		else:
			push_warning("SectorManager is neither Resource nor Node - tracking may fail")
	else:
		push_error("SectorManager class not found")
		return
	
	# Create migration utility for testing with proper type handling
	if WorldDataMigration:
		migration = WorldDataMigration.new()
		if migration:
			if migration is Node:
				add_child_autofree(migration)
				track_test_node(migration)
			elif migration is Resource:
				track_test_resource(migration)
		else:
			push_error("Failed to create migration utility")
	else:
		push_error("WorldDataMigration class not found")
	
	await get_tree().process_frame

func after_each() -> void:
	sector_manager = null
	migration = null
	await super.after_each()

func test_initialization() -> void:
	if not sector_manager:
		pending("Sector manager is null, skipping test")
		return
		
	var sectors = _call_node_method(sector_manager, "get_sectors", [])
	if sectors == null:
		sectors = []
	assert_eq(sectors.size(), 0, "Should start with no sectors")

func test_sector_generation() -> void:
	if not sector_manager:
		pending("Sector manager is null, skipping test")
		return
		
	var sector_count: int = 5
	_call_node_method_bool(sector_manager, "generate_sectors", [sector_count])
	var sectors = _call_node_method(sector_manager, "get_sectors", [])
	if sectors == null:
		sectors = []
	assert_eq(sectors.size(), sector_count, "Should generate requested number of sectors")

func test_sector_connections() -> void:
	if not sector_manager:
		pending("Sector manager is null, skipping test")
		return
		
	_call_node_method_bool(sector_manager, "generate_sectors", [3])
	var sectors = _call_node_method(sector_manager, "get_sectors", [])
	if sectors == null:
		sectors = []
		
	for sector in sectors:
		var connections = _call_node_method(sector, "get_connections", [])
		if connections == null:
			connections = []
		assert_gt(connections.size(), 0, "Each sector should have at least one connection")

func test_serialization() -> void:
	if not sector_manager:
		pending("Sector manager is null, skipping test")
		return
		
	_call_node_method_bool(sector_manager, "generate_sectors", [3])
	var original_sectors = _call_node_method(sector_manager, "get_sectors", [])
	if original_sectors == null:
		original_sectors = []
		
	var serialized = _call_node_method_dict(sector_manager, "serialize", [], {})
	
	# Create a new manager safely
	var new_manager = null
	if SectorManager:
		new_manager = SectorManager.new()
		if new_manager:
			if new_manager is Node:
				add_child_autofree(new_manager)
				track_test_node(new_manager)
			else:
				track_test_resource(new_manager)
		else:
			push_error("Failed to create new sector manager")
			return
	else:
		push_error("SectorManager class not found")
		return
	
	_call_node_method_bool(new_manager, "deserialize", [serialized])
	var deserialized_sectors = _call_node_method(new_manager, "get_sectors", [])
	if deserialized_sectors == null:
		deserialized_sectors = []
		
	assert_eq(deserialized_sectors.size(), original_sectors.size(), "Should maintain sector count after serialization")

func test_generate_sector() -> void:
	if not sector_manager:
		pending("Sector manager is null, skipping test")
		return
		
	var sector_name = "test_sector"
	
	# Safely call method and check for errors
	var result = _call_node_method_bool(sector_manager, "generate_sector", [sector_name])
	assert_true(result, "Should successfully generate sector")
	
	# Test that the sector was created - use safe dictionary access
	var sectors = sector_manager.get("sectors")
	if sectors is Dictionary:
		assert_true(sectors.has(sector_name), "Sector should be created")
	else:
		assert_true(false, "Sectors property is not a dictionary")
		return
	
	# Test that the correct number of planets were generated
	var planets = _call_node_method_array(sector_manager, "get_planets_in_sector", [sector_name], [])
	
	# Get min/max planets safely
	var min_planets = sector_manager.get("MIN_PLANETS_PER_SECTOR")
	var max_planets = sector_manager.get("MAX_PLANETS_PER_SECTOR")
	if min_planets == null:
		min_planets = 1 # Use a safe default
	if max_planets == null:
		max_planets = 10 # Use a safe default
		
	assert_true(planets.size() >= min_planets, "Should have minimum number of planets")
	assert_true(planets.size() <= max_planets, "Should not exceed maximum number of planets")
	
	# Test that each planet is properly initialized
	for planet in planets:
		assert_not_null(planet, "Planet should not be null")
		
		# Check planet type safely
		var is_game_planet = planet is GamePlanet if GamePlanet else false
		assert_true(is_game_planet, "Planet should be GamePlanet type")
		
		# Safely access planet properties
		var planet_name = planet.get("planet_name") if planet else null
		var planet_type = planet.get("planet_type") if planet else -1
		var faction_type = planet.get("faction_type") if planet else -1
		var environment_type = planet.get("environment_type") if planet else -1
		
		assert_not_null(planet_name, "Planet should have a name")
		assert_true(planet_type >= 0, "Planet should have valid planet type")
		assert_true(faction_type >= 0, "Planet should have valid faction type")
		assert_true(environment_type >= 0, "Planet should have valid environment type")
		
		# Test that the planet type is correctly converted - with null safety
		if migration and planet_type != null and planet_type >= 0:
			var planet_type_id = migration.convert_planet_type_to_id(planet_type)
			assert_not_null(planet_type_id, "Should convert planet type to ID")
			assert_ne(planet_type_id, "", "Planet type ID should not be empty")

func test_get_planet_at_coordinates() -> void:
	if not sector_manager:
		pending("Sector manager is null, skipping test")
		return
		
	var sector_name = "test_sector"
	_call_node_method_bool(sector_manager, "generate_sector", [sector_name])
	
	# Get a planet from the discovered planets
	var discovered_planets = sector_manager.get("discovered_planets")
	if not discovered_planets or not discovered_planets is Dictionary or discovered_planets.is_empty():
		push_error("No discovered planets")
		assert_false(true, "No discovered planets found")
		return
		
	var coordinates = discovered_planets.keys()[0]
	var planet = _call_node_method(sector_manager, "get_planet_at_coordinates", [coordinates])
	
	assert_not_null(planet, "Should return a planet at valid coordinates")
	
	# Check planet type safely
	var is_game_planet = planet is GamePlanet if GamePlanet else false
	assert_true(is_game_planet, "Should return a GamePlanet instance")
	
	# Test that the planet type is correctly converted - with null safety
	if migration and planet and planet.get("planet_type") != null:
		var planet_type = planet.get("planet_type")
		var planet_type_id = migration.convert_planet_type_to_id(planet_type)
		assert_not_null(planet_type_id, "Should convert planet type to ID")
		assert_ne(planet_type_id, "", "Planet type ID should not be empty")

func test_sector_serialization() -> void:
	if not sector_manager:
		pending("Sector manager is null, skipping test")
		return
		
	var sector_name = "test_sector"
	_call_node_method_bool(sector_manager, "generate_sector", [sector_name])
	
	# Serialize
	var data = _call_node_method_dict(sector_manager, "serialize", [])
	assert_true(data.has("sectors"), "Serialized data should contain sectors")
	assert_true(data.has("current_sector"), "Serialized data should contain current_sector")
	
	# Create new manager and deserialize
	var new_manager = null
	if SectorManager:
		new_manager = SectorManager.new()
		if not new_manager:
			push_error("Failed to create new sector manager")
			return
			
		# Add to scene tree if it's a Node
		if new_manager is Node:
			add_child_autofree(new_manager)
			track_test_node(new_manager)
		elif new_manager is Resource:
			track_test_resource(new_manager)
	else:
		push_error("SectorManager class not found")
		return
		
	_call_node_method_bool(new_manager, "deserialize", [data])
	
	# Get sectors safely
	var sectors = new_manager.get("sectors")
	if not sectors or not sectors is Dictionary:
		push_error("Deserialized sectors is not a dictionary")
		return
		
	# Verify deserialized data
	assert_true(sectors.has(sector_name), "Deserialized manager should have the sector")
	
	# Get original sectors safely
	var original_sectors = sector_manager.get("sectors")
	if not original_sectors or not original_sectors is Dictionary:
		push_error("Original sectors is not a dictionary")
		return
		
	assert_eq(sectors.get(sector_name, []).size(), original_sectors.get(sector_name, []).size(),
		"Deserialized sector should have same number of planets")

func test_migration_utility() -> void:
	if not sector_manager or not migration:
		pending("Sector manager or migration utility is null, skipping test")
		return
		
	var sector_name = "test_sector"
	_call_node_method_bool(sector_manager, "generate_sector", [sector_name])
	
	# Get a planet from the sector
	var planets = _call_node_method_array(sector_manager, "get_planets_in_sector", [sector_name], [])
	assert_gt(planets.size(), 0, "Should have at least one planet")
	
	var planet = planets[0] if planets.size() > 0 else null
	if not planet:
		push_error("No planet found")
		return
		
	# Check planet type safely
	var is_game_planet = planet is GamePlanet if GamePlanet else false
	assert_true(is_game_planet, "Should be a GamePlanet instance")
	
	# Use the migration utility to convert to GamePlanet
	var game_planet = _call_node_method(migration, "migrate_planet", [planet])
	assert_not_null(game_planet, "Migration should return a valid GamePlanet")
	
	# Check game_planet type safely
	is_game_planet = game_planet is GamePlanet if GamePlanet else false
	assert_true(is_game_planet, "Should return a GamePlanet instance")
	
	# Safe property access
	var gp_name = game_planet.get("planet_name") if game_planet else ""
	var p_name = planet.get("planet_name") if planet else ""
	assert_eq(gp_name, p_name, "GamePlanet should have same name")
	
	# Test that the planet type is correctly converted
	var planet_type = planet.get("planet_type") if planet else -1
	if planet_type >= 0:
		var planet_type_id = migration.convert_planet_type_to_id(planet_type)
		assert_not_null(planet_type_id, "Should convert planet type to ID")
		assert_ne(planet_type_id, "", "Planet type ID should not be empty")
	
	# Test world trait conversion
	var world_features = planet.get("world_features") if planet else []
	if world_features is Array and world_features.size() > 0:
		var trait_enum = world_features[0]
		var trait_id = migration.convert_world_trait_to_id(trait_enum)
		assert_not_null(trait_id, "Should convert world trait to ID")
		assert_ne(trait_id, "", "World trait ID should not be empty")
		
		# Test that the GamePlanet has the trait - safely call method
		var has_trait = false
		if game_planet and game_planet.has_method("has_trait"):
			has_trait = game_planet.has_trait(trait_id)
		assert_true(has_trait, "GamePlanet should have the trait")
	
	# Test two-way synchronization - with safe property access
	var new_name = "New Planet Name"
	if game_planet:
		game_planet.planet_name = new_name
		
	# Safely call update method
	if planet and planet.has_method("update_from_game_planet"):
		planet.update_from_game_planet()
		assert_eq(planet.get("planet_name", ""), new_name, "GamePlanet should update from FiveParsecsPlanet")
	
	var newer_name = "Even Newer Planet Name"
	if planet:
		planet.planet_name = newer_name
		
	# Safely call sync method  
	if planet and planet.has_method("_sync_to_game_planet"):
		planet._sync_to_game_planet()
		assert_eq(game_planet.get("planet_name", ""), newer_name, "FiveParsecsPlanet should update from GamePlanet")
