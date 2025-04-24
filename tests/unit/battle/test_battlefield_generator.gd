## Battlefield Generator Test Suite
## Tests the functionality of the battlefield generation system including:
## - Mission generation and validation
## - Battlefield size calculations and constraints
## - Terrain feature placement and validation
## - Performance benchmarks for large-scale generation
## - Error boundary testing
## - Signal emission verification
@tool
extends "res://tests/fixtures/specialized/battle_test.gd"

# Type-safe script references
const BattlefieldGenerator: GDScript = preload("res://src/core/systems/BattlefieldGenerator.gd")
const TerrainTypes: GDScript = preload("res://src/core/terrain/TerrainTypes.gd")
const TerrainRules: GDScript = preload("res://src/core/terrain/TerrainRules.gd")

# Factory functions for data objects

# Create a battlefield data object
static func create_battlefield_data() -> Dictionary:
	return {
		"size": Vector2i(),
		"terrain": [],
		"player_deployment_zone": [],
		"enemy_deployment_zone": [],
		"objectives": {}
	}

# Create a terrain data object
static func create_terrain_data() -> Dictionary:
	return {
		"type": - 1,
		"position": Vector2i(),
		"modifiers": []
	}

# Create a mock mission resource for testing
class MockMissionResource extends Resource:
	var type: int = GameEnums.MissionType.PATROL
	var difficulty: int = GameEnums.DifficultyLevel.NORMAL
	var environment: int = GameEnums.PlanetEnvironment.URBAN
	var objective: int = GameEnums.MissionObjective.PATROL
	var size: Vector2i = Vector2i(20, 20)
	
	func get_type() -> int:
		return type
	
	func get_difficulty() -> int:
		return difficulty
	
	func get_environment() -> int:
		return environment
	
	func get_objective() -> int:
		return objective
	
	func get_size() -> Vector2i:
		return size

# Create a test mission object - implements the parent class interface
func create_test_mission() -> Resource:
	var mission = MockMissionResource.new()
	return mission

# For internal use within the test class - get property from Resource or Dictionary
func _get_mission_property(mission, property: String, default_value = null):
	if mission is Dictionary:
		return mission.get(property, default_value)
	elif mission is Resource:
		var getter_method = "get_" + property
		if mission.has_method(getter_method):
			return mission.call(getter_method)
		elif property in mission:
			return mission.get(property)
	return default_value

# Compatibility for tests using Dictionary missions
func _create_test_mission_dict() -> Dictionary:
	return {
		"type": GameEnums.MissionType.PATROL,
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"environment": GameEnums.PlanetEnvironment.URBAN,
		"objective": GameEnums.MissionObjective.PATROL,
		"size": Vector2i(20, 20)
	}

# Type-safe constants
const DEFAULT_MIN_SIZE := Vector2i(10, 10)
const DEFAULT_MAX_SIZE := Vector2i(30, 30)
const BATTLEFIELD_GEN_THRESHOLD := 100
const TERRAIN_UPDATE_THRESHOLD := 50
const TEST_ITERATIONS := 10
const STRESS_TEST_SIZE := Vector2i(100, 100)
const TEST_TIMEOUT: float = 2.0

# Type-safe instance variables
var _generator: Node = null
var _terrain_rules: Node = null
var _signal_received: bool = false

# Test data
var _test_battlefield: Dictionary = {}
var _test_mission: Dictionary = {}
# Game object references for tests
var _player_team: Node2D = null
var _enemy_team: Node2D = null

# The Character class is used for testing
class TestCharacter extends Node2D:
	var id: String = ""
	var character_key: String = ""
	var type: int = 0 # Character.Type equivalent
	var team_id: String = ""
	var health: int = 1
	
	# Character.Type enum equivalent
	enum Type {CREW, ENEMY}

# Safe Property Access Methods
func _get_battlefield_property(battlefield: Dictionary, property: String, default_value: Variant) -> Variant:
	if battlefield.is_empty():
		push_error("Trying to access property '%s' on empty battlefield" % property)
		return default_value
	
	return battlefield.get(property, default_value)

func _get_terrain_property(terrain: Dictionary, property: String, default_value: Variant) -> Variant:
	if terrain.is_empty():
		push_error("Trying to access property '%s' on empty terrain" % property)
		return default_value
	
	return terrain.get(property, default_value)

# Helper Methods
func _create_test_mission_with_type(type: int = GameEnums.MissionType.PATROL) -> Resource:
	if not _generator or not _generator.has_method("generate_mission"):
		push_error("BattlefieldGenerator missing generate_mission method")
		return null
		
	var mission := create_test_mission()
	if mission is Resource:
		mission.type = type
		return mission
	return null

func _create_battlefield(config: Dictionary) -> Dictionary:
	if not _generator or not _generator.has_method("generate_battlefield"):
		push_error("BattlefieldGenerator missing generate_battlefield method")
		return {}
	
	var battlefield_dict: Dictionary = TypeSafeMixin._call_node_method_dict(_generator, "generate_battlefield", [config])
	if battlefield_dict.is_empty():
		return {}
		
	return _convert_battlefield_data(battlefield_dict)

func _convert_terrain_data(terrain_array: Array) -> Array:
	var result: Array = []
	
	# Handle the case where terrain_array is a 2D array (rows and columns)
	if terrain_array.size() > 0 and terrain_array[0] is Array:
		# It's a 2D array structure
		for x in range(terrain_array.size()):
			for y in range(terrain_array[x].size()):
				var terrain_cell = terrain_array[x][y]
				if terrain_cell is Dictionary:
					var terrain := create_terrain_data()
					terrain.type = terrain_cell.get("type", -1)
					terrain.position = Vector2i(x, y) # Use grid position
					terrain.modifiers = terrain_cell.get("modifiers", [])
					result.append(terrain)
		return result
	
	# Handle the case where terrain_array is a flat array of terrain dictionaries
	for terrain_dict in terrain_array:
		if not terrain_dict is Dictionary:
			continue
			
		var terrain := create_terrain_data()
		terrain.type = terrain_dict.get("type", -1)
		terrain.position = terrain_dict.get("position", Vector2i())
		terrain.modifiers = terrain_dict.get("modifiers", [])
		result.append(terrain)
	
	return result

func _convert_battlefield_data(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
		
	var battlefield := create_battlefield_data()
	
	# Handle size
	var size_data: Variant = data.get("size")
	if size_data is Vector2i:
		battlefield.size = size_data
	else:
		battlefield.size = Vector2i()
	
	# Handle terrain
	var terrain_array: Array = data.get("terrain", [])
	battlefield.terrain = _convert_terrain_data(terrain_array)
	
	# Handle deployment zones
	var player_zone_array: Array = data.get("player_deployment_zone", [])
	battlefield.player_deployment_zone = _convert_vector2_array(player_zone_array)
	
	var enemy_zone_array: Array = data.get("enemy_deployment_zone", [])
	battlefield.enemy_deployment_zone = _convert_vector2_array(enemy_zone_array)
	
	# Handle objectives
	battlefield.objectives = data.get("objectives", {})
	return battlefield

func _convert_vector2_array(data: Array) -> Array:
	var result: Array = []
	for item in data:
		if item is Vector2 or item is Vector2i:
			result.append(item)
	return result

func _get_min_distance_between_zones(zone1: Array, zone2: Array) -> float:
	var min_distance := 999999.0
	for pos1: Vector2 in zone1:
		for pos2: Vector2 in zone2:
			var distance := pos1.distance_to(pos2)
			min_distance = min(min_distance, distance)
	return min_distance

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize objects - handle the case where the generator might be a Resource
	var generator_instance = BattlefieldGenerator.new()
	
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
		
		# Use Callable to create and assign the method
		_generator.set("get_meta", Callable(gen_instance, "get_meta") if gen_instance.has_method("get_meta") else
			func(key): return null)
		
		# Use Callable for generate_battlefield
		_generator.set("generate_battlefield", Callable(gen_instance, "generate_battlefield") if gen_instance.has_method("generate_battlefield") else
			func(config): return {})
	else:
		push_error("Failed to create BattlefieldGenerator instance")
	
	add_child(_generator)
	track_test_node(_generator)
	
	# Initialize game objects
	_player_team = TestCharacter.new()
	_player_team.id = "crew"
	_player_team.character_key = "leader"
	_player_team.type = TestCharacter.Type.CREW
	_player_team.team_id = "player"
	_player_team.health = 5
	
	_enemy_team = TestCharacter.new()
	_enemy_team.id = "enemy"
	_enemy_team.character_key = "thug"
	_enemy_team.type = TestCharacter.Type.ENEMY
	_enemy_team.team_id = "enemy"
	_enemy_team.health = 8

func after_each() -> void:
	_generator = null
	_terrain_rules = null
	_test_battlefield = {}
	_test_mission = {}
	await super.after_each()

# Signal Handlers
func _on_generation_started() -> void:
	_signal_received = true

func _on_generation_completed() -> void:
	_signal_received = true

# Battlefield Size Tests
func test_battlefield_dimensions() -> void:
	var config: Dictionary = {"mission_type": GameEnums.MissionType.PATROL}
	var battlefield: Dictionary = _create_battlefield(config)
	
	assert_not_null(battlefield, "Battlefield should not be null")
	var size: Vector2i = _get_battlefield_property(battlefield, "size", Vector2i())
	assert_gt(size.x, 0, "Battlefield width should be greater than 0")
	assert_gt(size.y, 0, "Battlefield height should be greater than 0")

# Terrain Generation Tests
func test_terrain_generation() -> void:
	var config = {
		"size": Vector2i(24, 24),
		"environment": GameEnums.PlanetEnvironment.URBAN,
		"cover_density": 0.2
	}
	
	var battlefield = _generator.generate_battlefield(config)
	
	# Basic checks
	assert_not_null(battlefield, "Battlefield should be generated")
	assert_has(battlefield, "terrain", "Battlefield should have terrain data")
	assert_has(battlefield, "walkable_tiles", "Battlefield should have walkable tiles")
	
	# Check battlefield size
	var size = battlefield.size
	var size_x = size.x if size is Vector2i else int(size.x)
	var size_y = size.y if size is Vector2i else int(size.y)
	
	# Check terrain data structure
	var terrain = battlefield.terrain
	assert_true(terrain is Array, "Terrain should be an array")
	
	if terrain.size() > 0 and terrain[0] is Array:
		# 2D array structure
		assert_eq(terrain.size(), size_x, "Terrain grid width should match config")
		if terrain[0].size() > 0:
			assert_eq(terrain[0].size(), size_y, "Terrain grid height should match config")
	
	# Verify deployment zones
	assert_has(battlefield, "deployment_zones", "Battlefield should have deployment zones")
	assert_has(battlefield.deployment_zones, "player", "Battlefield should have player deployment zone")
	assert_has(battlefield.deployment_zones, "enemy", "Battlefield should have enemy deployment zone")

# Deployment Zone Tests
func test_deployment_zones() -> void:
	var config: Dictionary = {"mission_type": GameEnums.MissionType.PATROL}
	var battlefield: Dictionary = _create_battlefield(config)
	
	# Check player deployment zone
	var player_zone_array: Array = _get_battlefield_property(battlefield, "player_deployment_zone", [])
	var player_zone: Array = _convert_vector2_array(player_zone_array)
	assert_not_null(player_zone, "Player deployment zone should exist")
	assert_gt(player_zone.size(), 0, "Player deployment zone should have positions")
	
	# Check enemy deployment zone
	var enemy_zone_array: Array = _get_battlefield_property(battlefield, "enemy_deployment_zone", [])
	var enemy_zone: Array = _convert_vector2_array(enemy_zone_array)
	assert_not_null(enemy_zone, "Enemy deployment zone should exist")
	assert_gt(enemy_zone.size(), 0, "Enemy deployment zone should have positions")
	
	# Check deployment zone separation
	var min_distance: float = _get_min_distance_between_zones(player_zone, enemy_zone)
	assert_gt(min_distance, 3, "Deployment zones should be separated by at least 3 tiles")
	
	# Test that there are clear paths between deployment zones
	if player_zone.size() > 0 and enemy_zone.size() > 0:
		var paths: Array = TypeSafeMixin._call_node_method_array(_generator, "find_clear_paths", [player_zone[0], enemy_zone[0]])
		assert_gt(paths.size(), 0, "Should have at least one clear path between deployment zones")

# Mission Type Tests
func test_mission_specific_terrain() -> void:
	# Test patrol mission
	var patrol_config: Dictionary = {"mission_type": GameEnums.MissionType.PATROL}
	var patrol_field: Dictionary = _create_battlefield(patrol_config)
	var patrol_objectives: Dictionary = _get_battlefield_property(patrol_field, "objectives", {})
	assert_has(patrol_objectives, "patrol_points", "Patrol mission should have patrol points")
	
	# Test sabotage mission
	var sabotage_config: Dictionary = {"mission_type": GameEnums.MissionType.SABOTAGE}
	var sabotage_field: Dictionary = _create_battlefield(sabotage_config)
	var sabotage_objectives: Dictionary = _get_battlefield_property(sabotage_field, "objectives", {})
	assert_has(sabotage_objectives, "target_points", "Sabotage mission should have target points")
	
	# Test rescue mission
	var rescue_config: Dictionary = {"mission_type": GameEnums.MissionType.RESCUE}
	var rescue_field: Dictionary = _create_battlefield(rescue_config)
	var rescue_objectives: Dictionary = _get_battlefield_property(rescue_field, "objectives", {})
	assert_has(rescue_objectives, "rescue_points", "Rescue mission should have rescue points")

# Cover Generation Tests
func test_cover_generation() -> void:
	var config: Dictionary = {"mission_type": GameEnums.MissionType.PATROL}
	var battlefield: Dictionary = _create_battlefield(config)
	
	var terrain_array: Array = _get_battlefield_property(battlefield, "terrain", [])
	var terrain: Array = _convert_terrain_data(terrain_array)
	var size_data: Vector2i = _get_battlefield_property(battlefield, "size", Vector2i())
	
	var cover_count: int = 0
	for feature: Dictionary in terrain:
		var feature_type: int = _get_terrain_property(feature, "type", -1)
		if feature_type == TerrainTypes.Type.COVER_LOW or feature_type == TerrainTypes.Type.COVER_HIGH:
			cover_count += 1
	
	assert_gt(cover_count, 0, "Should have cover features")
	assert_lt(cover_count, (size_data.x * size_data.y) / 4.0, "Cover should not occupy more than 25% of the battlefield")

# Line of Sight Tests
func test_line_of_sight_paths() -> void:
	var config: Dictionary = {"mission_type": GameEnums.MissionType.PATROL}
	var battlefield: Dictionary = _create_battlefield(config)
	
	var player_zone_array: Array = _get_battlefield_property(battlefield, "player_deployment_zone", [])
	var enemy_zone_array: Array = _get_battlefield_property(battlefield, "enemy_deployment_zone", [])
	
	var player_zone: Array = _convert_vector2_array(player_zone_array)
	var enemy_zone: Array = _convert_vector2_array(enemy_zone_array)
	
	# Test that there are clear paths between deployment zones
	if player_zone.size() > 0 and enemy_zone.size() > 0:
		var paths: Array = TypeSafeMixin._call_node_method_array(_generator, "find_clear_paths", [player_zone[0], enemy_zone[0]])
		assert_gt(paths.size(), 0, "Should have at least one clear path between deployment zones")

# Terrain Effects Tests
func test_terrain_effects() -> void:
	var config: Dictionary = {"mission_type": GameEnums.MissionType.PATROL}
	var battlefield: Dictionary = _create_battlefield(config)
	var terrain_array: Array = _get_battlefield_property(battlefield, "terrain", [])
	var terrain: Array = _convert_terrain_data(terrain_array)
	
	for feature: Dictionary in terrain:
		var feature_type: int = _get_terrain_property(feature, "type", -1)
		match feature_type:
			TerrainTypes.Type.COVER_HIGH:
				var modifiers: Array = TypeSafeMixin._call_node_method_array(_terrain_rules, "get_feature_modifiers", [GameEnums.TerrainFeatureType.OBSTACLE])
				assert_true(GameEnums.TerrainModifier.FULL_COVER in modifiers,
					"High cover should provide full cover")
			
			TerrainTypes.Type.COVER_LOW:
				var modifiers: Array = TypeSafeMixin._call_node_method_array(_terrain_rules, "get_feature_modifiers", [GameEnums.TerrainFeatureType.COVER])
				assert_true(GameEnums.TerrainModifier.PARTIAL_COVER in modifiers,
					"Low cover should provide partial cover")
			
			TerrainTypes.Type.HAZARD:
				var modifiers: Array = TypeSafeMixin._call_node_method_array(_terrain_rules, "get_feature_modifiers", [GameEnums.TerrainFeatureType.HAZARD])
				assert_true(GameEnums.TerrainModifier.HAZARDOUS in modifiers,
					"Hazard should be hazardous")
				assert_true(GameEnums.TerrainModifier.MOVEMENT_PENALTY in modifiers,
					"Hazard should penalize movement")
			
			TerrainTypes.Type.DIFFICULT:
				var modifiers: Array = TypeSafeMixin._call_node_method_array(_terrain_rules, "get_feature_modifiers", [GameEnums.TerrainFeatureType.OBSTACLE])
				assert_true(GameEnums.TerrainModifier.DIFFICULT_TERRAIN in modifiers,
					"Difficult terrain should have movement penalty")

# Environment Type Tests
func test_environment_types() -> void:
	var config: Dictionary = {
		"mission_type": GameEnums.MissionType.PATROL,
		"environment": GameEnums.PlanetEnvironment.URBAN
	}
	var urban_battlefield := _create_battlefield(config)
	if not urban_battlefield:
		push_error("Failed to create urban battlefield")
		return
	
	# Check that urban environment has appropriate modifiers
	var urban_modifiers: Array = TypeSafeMixin._call_node_method_array(_terrain_rules, "get_terrain_modifiers", [GameEnums.PlanetEnvironment.URBAN])
	assert_true(GameEnums.TerrainModifier.COVER_BONUS in urban_modifiers,
		"Urban environment should provide cover bonus")
	assert_true(GameEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED in urban_modifiers,
		"Urban environment should affect line of sight")
	
	# Test forest environment
	config["environment"] = GameEnums.PlanetEnvironment.FOREST
	var forest_battlefield := _create_battlefield(config)
	if not forest_battlefield:
		push_error("Failed to create forest battlefield")
		return
	var forest_modifiers: Array = TypeSafeMixin._call_node_method_array(_terrain_rules, "get_terrain_modifiers", [GameEnums.PlanetEnvironment.FOREST])
	assert_true(GameEnums.TerrainModifier.DIFFICULT_TERRAIN in forest_modifiers,
		"Forest should be difficult terrain")
	assert_true(GameEnums.TerrainModifier.COVER_BONUS in forest_modifiers,
		"Forest should provide cover bonus")
	
	# Test hazardous environment
	config["environment"] = GameEnums.PlanetEnvironment.HAZARDOUS
	var hazard_battlefield := _create_battlefield(config)
	if not hazard_battlefield:
		push_error("Failed to create hazardous battlefield")
		return
	var hazard_modifiers: Array = TypeSafeMixin._call_node_method_array(_terrain_rules, "get_terrain_modifiers", [GameEnums.PlanetEnvironment.HAZARDOUS])
	assert_true(GameEnums.TerrainModifier.HAZARDOUS in hazard_modifiers,
		"Hazardous environment should be hazardous")
	assert_true(GameEnums.TerrainModifier.MOVEMENT_PENALTY in hazard_modifiers,
		"Hazardous environment should penalize movement")

# Unit Tests
func test_generate_mission() -> void:
	var mission = create_test_mission()
	if mission is Resource:
		track_test_resource(mission)
	
	assert_not_null(mission, "Mission should be created")
	
	var mission_type: int = _get_mission_property(mission, "type", -1)
	assert_true(mission_type in GameEnums.MissionType.values(),
		"Mission type should be valid: %s" % GameEnums.MissionType.keys()[mission_type])
	
	var difficulty: int = _get_mission_property(mission, "difficulty", -1)
	assert_true(difficulty in GameEnums.DifficultyLevel.values(),
		"Difficulty should be valid: %s" % GameEnums.DifficultyLevel.keys()[difficulty])
	
	var environment: int = _get_mission_property(mission, "environment", -1)
	assert_true(environment in GameEnums.PlanetEnvironment.values(),
		"Environment should be valid: %s" % GameEnums.PlanetEnvironment.keys()[environment])
	
	var objective: int = _get_mission_property(mission, "objective", -1)
	assert_true(objective in GameEnums.MissionObjective.values(),
		"Objective should be valid: %s" % GameEnums.MissionObjective.keys()[objective])

func test_battlefield_size() -> void:
	var mission = create_test_mission()
	if mission is Resource:
		track_test_resource(mission)
	
	# Safely get battlefield size with proper type handling
	var result = TypeSafeMixin._call_node_method(_generator, "get_battlefield_size", [mission])
	var size_data: Vector2i
	
	# Handle different result types
	if result is Vector2i:
		size_data = result
	elif result is Vector2:
		# Convert Vector2 to Vector2i
		size_data = Vector2i(int(result.x), int(result.y))
	else:
		# Handle unexpected result type
		push_warning("Unexpected result type from get_battlefield_size: " + str(typeof(result)))
		size_data = Vector2i(0, 0)
	
	assert_true(size_data.x > 0 and size_data.y > 0, "Battlefield should have positive dimensions")
	assert_true(size_data.x <= DEFAULT_MAX_SIZE.x and size_data.y <= DEFAULT_MAX_SIZE.y,
		"Battlefield should not exceed maximum size")
	assert_true(size_data.x >= DEFAULT_MIN_SIZE.x and size_data.y >= DEFAULT_MIN_SIZE.y,
		"Battlefield should meet minimum size requirements")

# Performance Tests
func test_battlefield_generation_performance() -> void:
	var mission = create_test_mission()
	if mission is Resource:
		track_test_resource(mission)
	
	# Test terrain generation performance
	var total_generations := 3 # Reduced from 10 to speed up tests
	var start_time := Time.get_ticks_msec()
	
	for i in range(total_generations):
		# Generate a complete battlefield directly with config
		var config = {
			"size": Vector2i(24, 24),
			"mission_type": GameEnums.MissionType.PATROL,
			"environment": GameEnums.PlanetEnvironment.URBAN,
		}
		
		var battlefield: Dictionary = _generator.generate_battlefield(config)
		
		assert_not_null(battlefield, "Battlefield should be generated")
		assert_true(battlefield.has("terrain"), "Battlefield should have terrain data")
		
		# Simple validation of terrain data
		var terrain: Array = battlefield.terrain
		assert_true(terrain.size() > 0, "Terrain array should not be empty")
	
	var end_time := Time.get_ticks_msec()
	var avg_time: float = float(end_time - start_time) / float(total_generations)
	
	# Print Performance metrics
	print("Average battlefield generation time: %0.2f ms" % avg_time)
	assert_true(avg_time < 1000.0, "Battlefield generation should be reasonably performant (< 1000ms)")

# Boundary Tests
func test_boundary_minimum_size() -> void:
	var config: Dictionary = {"size": Vector2i(1, 1)}
	var battlefield: Dictionary = _create_battlefield(config)
	var size_data: Vector2i = _get_battlefield_property(battlefield, "size", Vector2i())
	assert_true(size_data >= DEFAULT_MIN_SIZE,
		"Battlefield should enforce minimum size")

func test_boundary_maximum_size() -> void:
	var config: Dictionary = {"size": Vector2i(1000, 1000)}
	var battlefield: Dictionary = _create_battlefield(config)
	var size_data: Vector2i = _get_battlefield_property(battlefield, "size", Vector2i())
	assert_true(size_data <= DEFAULT_MAX_SIZE,
		"Battlefield should enforce maximum size")

# Signal Tests
func test_signals_generation_started() -> void:
	_signal_received = false
	if not _generator.has_signal("generation_started"):
		push_error("BattlefieldGenerator missing generation_started signal")
		return
		
	var connect_result := _generator.connect("generation_started", _on_generation_started)
	if connect_result != OK:
		push_error("Failed to connect generation_started signal")
		return
		
	var config := {"size": DEFAULT_MIN_SIZE}
	assert_not_null(_create_battlefield(config), "Battlefield creation should succeed")
	assert_true(_signal_received, "Generation started signal should be emitted")

func test_signals_generation_completed() -> void:
	_signal_received = false
	if not _generator.has_signal("generation_completed"):
		push_error("BattlefieldGenerator missing generation_completed signal")
		return
		
	var connect_result := _generator.connect("generation_completed", _on_generation_completed)
	if connect_result != OK:
		push_error("Failed to connect generation_completed signal")
		return
		
	var config := {"size": DEFAULT_MIN_SIZE}
	assert_not_null(_create_battlefield(config), "Battlefield creation should succeed")
	assert_true(_signal_received, "Generation completed signal should be emitted")

# Error Tests
func test_error_invalid_mission_type() -> void:
	var mission_dict: Dictionary = _create_test_mission_dict()
	var result: Dictionary = TypeSafeMixin._call_node_method_dict(_generator, "generate_battlefield_for_mission", [mission_dict])
	assert_true(result.is_empty(), "Invalid mission type should return empty result")

func test_battlefield_initialization() -> void:
	var config = {
		"size": Vector2i(24, 24),
		"environment": GameEnums.PlanetEnvironment.URBAN,
		"cover_density": 0.2
	}
	
	var battlefield = _generator.generate_battlefield(config)
	var battlefield_node = _create_battlefield_node(battlefield)
	
	assert_not_null(battlefield_node, "Battlefield node should be created")
	assert_true(battlefield_node is Node2D, "Battlefield should be a Node2D")
	
	# Verify cell nodes
	var cells = battlefield_node.get_children().filter(func(node): return node.name.begins_with("Cell"))
	assert_true(cells.size() > 0, "Battlefield should have cell nodes")
	
	# Verify deployment zones
	var deployment_zones = battlefield_node.get_children().filter(func(node): return node.name.begins_with("DeploymentZone"))
	assert_true(deployment_zones.size() > 0, "Battlefield should have deployment zone nodes")
	
	# Clean up
	battlefield_node.queue_free()
	await get_tree().process_frame

func test_character_placement() -> void:
	var config = {
		"size": Vector2i(24, 24),
		"environment": GameEnums.PlanetEnvironment.URBAN,
		"cover_density": 0.2
	}
	
	var battlefield = _generator.generate_battlefield(config)
	var battlefield_node = _create_battlefield_node(battlefield)
	
	# Get deployment zones
	var deployment_zones = battlefield.get("deployment_zones", {})
	if deployment_zones.is_empty() or not deployment_zones.has("player") or not deployment_zones.has("enemy"):
		push_error("Battlefield has no valid deployment zones")
		battlefield_node.queue_free()
		return
	
	var player_zones = deployment_zones.get("player", [])
	var enemy_zones = deployment_zones.get("enemy", [])
	
	if player_zones.is_empty() or enemy_zones.is_empty():
		push_error("Empty deployment zones")
		battlefield_node.queue_free()
		return
	
	# Place player character
	var player_pos = player_zones[0]
	var player_pos_vec: Vector2
	if player_pos is Vector2i:
		player_pos_vec = Vector2(player_pos.x, player_pos.y)
	elif player_pos is Vector2:
		player_pos_vec = player_pos
	else:
		push_error("Invalid player position type")
		battlefield_node.queue_free()
		return
	
	_player_team.position = player_pos_vec * battlefield_node.get_meta("cell_size")
	battlefield_node.add_child(_player_team)
	
	# Place enemy character
	var enemy_pos = enemy_zones[0]
	var enemy_pos_vec: Vector2
	if enemy_pos is Vector2i:
		enemy_pos_vec = Vector2(enemy_pos.x, enemy_pos.y)
	elif enemy_pos is Vector2:
		enemy_pos_vec = enemy_pos
	else:
		push_error("Invalid enemy position type")
		battlefield_node.queue_free()
		return
	
	_enemy_team.position = enemy_pos_vec * battlefield_node.get_meta("cell_size")
	battlefield_node.add_child(_enemy_team)
	
	# Verify characters are at correct positions
	assert_eq(_player_team.position, player_pos_vec * battlefield_node.get_meta("cell_size"),
		"Player should be at designated position")
	assert_eq(_enemy_team.position, enemy_pos_vec * battlefield_node.get_meta("cell_size"),
		"Enemy should be at designated position")
	
	# Check if walkable_tiles exists
	if battlefield.has("walkable_tiles"):
		var walkable_tiles = battlefield.walkable_tiles
		var player_pos_for_check
		var enemy_pos_for_check
		
		if walkable_tiles.size() > 0:
			# Check type of first walkable tile to determine what we need to compare with
			var first_tile = walkable_tiles[0]
			if first_tile is Vector2i:
				player_pos_for_check = Vector2i(int(player_pos.x), int(player_pos.y))
				enemy_pos_for_check = Vector2i(int(enemy_pos.x), int(enemy_pos.y))
			else:
				player_pos_for_check = player_pos
				enemy_pos_for_check = enemy_pos
			
			# Check if positions are walkable
			var player_walkable = false
			var enemy_walkable = false
			
			for tile in walkable_tiles:
				if (tile is Vector2i and player_pos_for_check is Vector2i and
						tile.x == player_pos_for_check.x and tile.y == player_pos_for_check.y):
					player_walkable = true
				elif (tile is Vector2 and player_pos_for_check is Vector2 and
						is_equal_approx(tile.x, player_pos_for_check.x) and is_equal_approx(tile.y, player_pos_for_check.y)):
					player_walkable = true
				
				if (tile is Vector2i and enemy_pos_for_check is Vector2i and
						tile.x == enemy_pos_for_check.x and tile.y == enemy_pos_for_check.y):
					enemy_walkable = true
				elif (tile is Vector2 and enemy_pos_for_check is Vector2 and
						is_equal_approx(tile.x, enemy_pos_for_check.x) and is_equal_approx(tile.y, enemy_pos_for_check.y)):
					enemy_walkable = true
			
			assert_true(player_walkable, "Player should be on walkable tile")
			assert_true(enemy_walkable, "Enemy should be on walkable tile")
	
	# Clean up
	battlefield_node.queue_free()
	await get_tree().process_frame

# Helper function to create a Battlefield node from generated data
func _create_battlefield_node(battlefield_data: Dictionary) -> Node2D:
	var battlefield = Node2D.new()
	battlefield.name = "Battlefield"
	battlefield.set_meta("cell_size", 64) # Define cell size for rendering as meta property
	
	add_child(battlefield)
	
	# Add cell visual representations
	var size = battlefield_data.get("size", Vector2i(10, 10))
	var size_x = size.x if size is Vector2i else int(size.x)
	var size_y = size.y if size is Vector2i else int(size.y)
	
	# Check terrain data structure
	var terrain_data = battlefield_data.get("terrain", [])
	var has_2d_terrain = terrain_data.size() > 0 and terrain_data is Array
	
	for x in range(size_x):
		for y in range(size_y):
			var cell_node = ColorRect.new()
			cell_node.name = "Cell_%d_%d" % [x, y]
			cell_node.size = Vector2(battlefield.get_meta("cell_size"), battlefield.get_meta("cell_size"))
			cell_node.position = Vector2(x, y) * battlefield.get_meta("cell_size")
			
			# Default color is light gray (empty)
			cell_node.color = Color.LIGHT_GRAY
			
			# Try to get cell data - handle different terrain formats
			var cell_type = TerrainTypes.Type.EMPTY
			if has_2d_terrain:
				if x < terrain_data.size() and terrain_data[x] is Array and y < terrain_data[x].size():
					var cell_data = terrain_data[x][y]
					if cell_data is Dictionary and cell_data.has("type"):
						cell_type = cell_data.type
			
			# Set cell color based on terrain type
			match cell_type:
				TerrainTypes.Type.WALL:
					cell_node.color = Color.BLACK
				TerrainTypes.Type.COVER_HIGH:
					cell_node.color = Color.DARK_GREEN
				TerrainTypes.Type.COVER_LOW:
					cell_node.color = Color.GREEN
				TerrainTypes.Type.DIFFICULT:
					cell_node.color = Color.BROWN
			
			battlefield.add_child(cell_node)
	
	# Add deployment zone markers
	var deployment_zones = battlefield_data.get("deployment_zones", {})
	for zone_name in deployment_zones:
		var zone = deployment_zones[zone_name]
		for pos in zone:
			var zone_marker = ColorRect.new()
			
			# Handle both Vector2 and Vector2i
			var pos_x = pos.x if (pos is Vector2 or pos is Vector2i) else 0
			var pos_y = pos.y if (pos is Vector2 or pos is Vector2i) else 0
			
			zone_marker.name = "DeploymentZone_%s_%d_%d" % [zone_name, pos_x, pos_y]
			zone_marker.size = Vector2(battlefield.get_meta("cell_size") / 2, battlefield.get_meta("cell_size") / 2)
			
			var pos_vec = Vector2(pos_x, pos_y)
			zone_marker.position = pos_vec * battlefield.get_meta("cell_size") + Vector2(battlefield.get_meta("cell_size") / 4, battlefield.get_meta("cell_size") / 4)
			
			# Set color based on zone (red for enemy, blue for player)
			zone_marker.color = Color.BLUE if zone_name == "player" else Color.RED
			
			battlefield.add_child(zone_marker)
	
	return battlefield
