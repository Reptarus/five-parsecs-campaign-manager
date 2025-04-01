@tool
extends "res://tests/fixtures/base/game_test.gd"

const BattlefieldGenerator = preload("res://src/core/systems/BattlefieldGenerator.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")
const WorldDataMigration = preload("res://src/core/migration/WorldDataMigration.gd")

var _generator: BattlefieldGenerator
var _migration: WorldDataMigration

func before_each() -> void:
	await super.before_each()
	
	# Initialize objects - handle the case where they might be Resources
	var generator_instance = BattlefieldGenerator.new()
	var migration_instance = WorldDataMigration.new()
	
	# Check if BattlefieldGenerator is a Node or Resource
	if generator_instance is Node:
		_generator = generator_instance
	elif generator_instance is Resource:
		# Create a Node wrapper for the Resource
		_generator = Node.new()
		_generator.set_name("BattlefieldGeneratorWrapper")
		_generator.set_meta("generator", generator_instance)
		
		# Store generator_instance in a variable that can be captured by the lambda
		var gen_instance = generator_instance
		
		# Use set() method to assign the callable
		_generator.set("generate_battlefield", Callable(gen_instance, "generate_battlefield") if gen_instance.has_method("generate_battlefield") else
			func(config): return {})
	else:
		push_error("Failed to create BattlefieldGenerator instance")
		
	# Check if WorldDataMigration is a Node or Resource
	if migration_instance is Node:
		_migration = migration_instance
	elif migration_instance is Resource:
		# Create a Node wrapper for the Resource
		_migration = Node.new()
		_migration.set_name("WorldDataMigrationWrapper")
		_migration.set_meta("migration", migration_instance)
		
		# Store migration_instance in a variable that can be captured by the lambda
		var migrate_instance = migration_instance
		
		# Use set() method to assign the callable
		_migration.set("convert_planet_environment_to_id", Callable(migrate_instance, "convert_planet_environment_to_id") if migrate_instance.has_method("convert_planet_environment_to_id") else
			func(env): return env)
	else:
		push_error("Failed to create WorldDataMigration instance")
	
	add_child(_generator)
	track_test_node(_generator)

func after_each() -> void:
	await super.after_each()
	_generator = null
	_migration = null

func test_terrain_generation_basic() -> void:
	var config = {
		"size": Vector2i(24, 24),
		"environment": _migration.convert_planet_environment_to_id(GameEnums.PlanetEnvironment.URBAN),
		"cover_density": 0.2
	}
	
	var battlefield = _generator.generate_battlefield(config)
	assert_not_null(battlefield, "Battlefield should be generated")
	assert_eq(battlefield.size, config.size, "Battlefield size should match config")
	
	# Verify terrain grid is properly initialized
	var terrain_data = battlefield.terrain
	assert_not_null(terrain_data, "Terrain data should exist")
	assert_eq(terrain_data.size(), config.size.x, "Terrain grid width should match config")
	assert_eq(terrain_data[0].row.size(), config.size.y, "Terrain grid height should match config")

func test_terrain_feature_distribution() -> void:
	var config = {
		"size": Vector2i(24, 24),
		"environment": _migration.convert_planet_environment_to_id(GameEnums.PlanetEnvironment.URBAN),
		"cover_density": 0.2
	}
	
	var battlefield = _generator.generate_battlefield(config)
	var feature_counts = {}
	
	# Count terrain features
	for x in range(config.size.x):
		for cell in battlefield.terrain[x].row:
			var type = cell.type
			if not feature_counts.has(type):
				feature_counts[type] = 0
			feature_counts[type] += 1
	
	# Verify minimum terrain features
	assert_true(feature_counts.size() > 1, "Should have multiple terrain types")
	assert_true(feature_counts.has(TerrainTypes.Type.WALL), "Should have walls in urban environment")
	assert_true(feature_counts.has(TerrainTypes.Type.COVER_LOW) or feature_counts.has(TerrainTypes.Type.COVER_HIGH),
		"Should have cover elements")

func test_terrain_validation() -> void:
	var config = {
		"size": Vector2i(24, 24),
		"environment": _migration.convert_planet_environment_to_id(GameEnums.PlanetEnvironment.URBAN),
		"cover_density": 0.2
	}
	
	var battlefield = _generator.generate_battlefield(config)
	
	# Test walkability
	assert_true(battlefield.walkable_tiles.size() > 0, "Should have walkable tiles")
	
	# Test deployment zones
	assert_true(battlefield.deployment_zones.has("player"), "Should have player deployment zone")
	assert_true(battlefield.deployment_zones.has("enemy"), "Should have enemy deployment zone")
	
	# Verify deployment zones are valid
	for zone_name in battlefield.deployment_zones:
		var zone = battlefield.deployment_zones[zone_name]
		assert_true(zone.size() > 0, "Deployment zone should have tiles")
		
		# Check deployment zone tiles are walkable
		for pos in zone:
			assert_true(pos in battlefield.walkable_tiles, "Deployment zone tiles should be walkable")

func test_environment_specific_generation() -> void:
	var environments = [
		GameEnums.PlanetEnvironment.URBAN,
		GameEnums.PlanetEnvironment.FOREST,
		GameEnums.PlanetEnvironment.DESERT
	]
	
	for env in environments:
		var env_id = _migration.convert_planet_environment_to_id(env)
		var config = {
			"size": Vector2i(24, 24),
			"environment": env_id,
			"cover_density": 0.2
		}
		
		var battlefield = _generator.generate_battlefield(config)
		assert_not_null(battlefield, "Should generate battlefield for environment: " + str(env_id))
		
		# Verify environment-specific features
		match env:
			GameEnums.PlanetEnvironment.URBAN:
				assert_true(_has_terrain_feature(battlefield, TerrainTypes.Type.WALL), "Urban should have walls")
			GameEnums.PlanetEnvironment.FOREST:
				assert_true(_has_terrain_feature(battlefield, TerrainTypes.Type.COVER_HIGH), "Forest should have high cover")
			GameEnums.PlanetEnvironment.DESERT:
				assert_true(_has_terrain_feature(battlefield, TerrainTypes.Type.DIFFICULT), "Desert should have difficult terrain")

func test_terrain_connectivity() -> void:
	var config = {
		"size": Vector2i(24, 24),
		"environment": _migration.convert_planet_environment_to_id(GameEnums.PlanetEnvironment.URBAN),
		"cover_density": 0.2
	}
	
	var battlefield = _generator.generate_battlefield(config)
	
	# Verify player can reach enemy deployment zone
	var player_zone = battlefield.deployment_zones["player"]
	var enemy_zone = battlefield.deployment_zones["enemy"]
	
	assert_true(_zones_are_connected(battlefield, player_zone[0], enemy_zone[0]),
		"Player should be able to reach enemy deployment zone")

# Helper function to check if battlefield has specific terrain feature
func _has_terrain_feature(battlefield: Dictionary, feature_type: TerrainTypes.Type) -> bool:
	# Safely handle battlefield size - it might be Vector2 or Vector2i
	var size_x = battlefield.size.x if battlefield.has("size") and battlefield.size is Vector2i else \
		int(battlefield.size.x) if battlefield.has("size") else 0
	
	for x in range(size_x):
		for cell in battlefield.terrain[x].row:
			if cell.type == feature_type:
				return true
	return false

# Helper function to check if two points are connected (simplified pathfinding check)
func _zones_are_connected(battlefield: Dictionary, start, end) -> bool:
	# Convert start/end to Vector2i if they're not already
	var start_vec = Vector2i(start.x, start.y) if start is Vector2 else start
	var end_vec = Vector2i(end.x, end.y) if end is Vector2 else end
	
	var visited = {}
	var to_visit = [start_vec]
	
	while to_visit.size() > 0:
		var current = to_visit.pop_front()
		if current == end_vec:
			return true
			
		if visited.has(current):
			continue
			
		visited[current] = true
		
		# Check adjacent tiles
		for dir in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var next = current + dir
			if next in battlefield.walkable_tiles and not visited.has(next):
				to_visit.append(next)
	
	return false