@tool
extends "res://tests/fixtures/base_test.gd"

## Test class for BattlefieldGenerator functionality
##
## Comprehensive test suite for the battlefield generation system including:
## - Mission generation and validation
## - Battlefield size calculations and constraints
## - Terrain feature placement and validation
## - Performance benchmarks for large-scale generation
## - Error boundary testing
## - Signal emission verification
##
## @class_name TestBattlefieldGenerator
## @author Your Team
## @version 1.0

const TestedClass = preload("res://src/core/battle/BattlefieldGenerator.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")
const TerrainRules = preload("res://src/core/terrain/TerrainRules.gd")

# Default size constraints for battlefield
const DEFAULT_MIN_SIZE := Vector2i(10, 10)
const DEFAULT_MAX_SIZE := Vector2i(30, 30)

# Performance thresholds (in milliseconds)
const BATTLEFIELD_GEN_THRESHOLD := 100
const TERRAIN_UPDATE_THRESHOLD := 50
const TEST_ITERATIONS := 10
const STRESS_TEST_SIZE := Vector2i(100, 100)

var _instance: TestedClass
var _terrain_rules: TerrainRules
var _signal_received: bool

# Helper Methods
func _create_test_mission(type: int = GameEnums.MissionType.PATROL) -> Resource:
	var mission = _instance.generate_mission()
	mission.type = type
	track_test_resource(mission)
	return mission

func _generate_large_battlefield() -> Dictionary:
	return _instance.generate_battlefield({"size": STRESS_TEST_SIZE})

func before_each() -> void:
	await super.before_each()
	_instance = TestedClass.new()
	_terrain_rules = TerrainRules.new()
	add_child(_instance)
	track_test_node(_instance)

func after_each() -> void:
	await super.after_each()
	_instance = null
	_terrain_rules = null

# Battlefield Size Tests
func test_battlefield_dimensions() -> void:
	var config = {"mission_type": GameEnums.MissionType.PATROL}
	var battlefield = _instance.generate_battlefield(config)
	
	assert_not_null(battlefield, "Battlefield should not be null")
	assert_gt(battlefield.size.x, 0, "Battlefield width should be greater than 0")
	assert_gt(battlefield.size.y, 0, "Battlefield height should be greater than 0")

# Terrain Generation Tests
func test_terrain_generation() -> void:
	var config = {"mission_type": GameEnums.MissionType.PATROL}
	var battlefield = _instance.generate_battlefield(config)
	
	# Check that terrain is generated
	assert_not_null(battlefield.terrain, "Terrain should not be null")
	assert_gt(battlefield.terrain.size(), 0, "Should have terrain features")
	
	# Check terrain types
	var terrain_types = []
	for feature in battlefield.terrain:
		if not feature.type in terrain_types:
			terrain_types.append(feature.type)
	
	assert_gt(terrain_types.size(), 1, "Should have multiple terrain types")

# Deployment Zone Tests
func test_deployment_zones() -> void:
	var config = {"mission_type": GameEnums.MissionType.PATROL}
	var battlefield = _instance.generate_battlefield(config)
	
	# Check player deployment zone
	assert_not_null(battlefield.player_deployment_zone, "Player deployment zone should exist")
	assert_gt(battlefield.player_deployment_zone.size(), 0, "Player deployment zone should have positions")
	
	# Check enemy deployment zone
	assert_not_null(battlefield.enemy_deployment_zone, "Enemy deployment zone should exist")
	assert_gt(battlefield.enemy_deployment_zone.size(), 0, "Enemy deployment zone should have positions")
	
	# Check deployment zone separation
	var min_distance = _get_min_distance_between_zones(
		battlefield.player_deployment_zone,
		battlefield.enemy_deployment_zone
	)
	assert_gt(min_distance, 3, "Deployment zones should be separated by at least 3 tiles")

# Mission Type Tests
func test_mission_specific_terrain() -> void:
	# Test patrol mission
	var patrol_config = {"mission_type": GameEnums.MissionType.PATROL}
	var patrol_field = _instance.generate_battlefield(patrol_config)
	assert_has(patrol_field.objectives, "patrol_points", "Patrol mission should have patrol points")
	
	# Test sabotage mission
	var sabotage_config = {"mission_type": GameEnums.MissionType.SABOTAGE}
	var sabotage_field = _instance.generate_battlefield(sabotage_config)
	assert_has(sabotage_field.objectives, "target_points", "Sabotage mission should have target points")
	
	# Test rescue mission
	var rescue_config = {"mission_type": GameEnums.MissionType.RESCUE}
	var rescue_field = _instance.generate_battlefield(rescue_config)
	assert_has(rescue_field.objectives, "rescue_points", "Rescue mission should have rescue points")

# Cover Generation Tests
func test_cover_generation() -> void:
	var config = {"mission_type": GameEnums.MissionType.PATROL}
	var battlefield = _instance.generate_battlefield(config)
	
	var cover_count = 0
	for feature in battlefield.terrain:
		if feature.type == TerrainTypes.Type.COVER_LOW or feature.type == TerrainTypes.Type.COVER_HIGH:
			cover_count += 1
	
	assert_gt(cover_count, 0, "Should have cover features")
	assert_lt(cover_count, battlefield.size.x * battlefield.size.y / 4,
		"Cover should not occupy more than 25% of the battlefield")

# Line of Sight Tests
func test_line_of_sight_paths() -> void:
	var config = {"mission_type": GameEnums.MissionType.PATROL}
	var battlefield = _instance.generate_battlefield(config)
	
	# Test that there are clear paths between deployment zones
	var paths = _instance.find_clear_paths(
		battlefield.player_deployment_zone[0],
		battlefield.enemy_deployment_zone[0]
	)
	
	assert_gt(paths.size(), 0, "Should have at least one clear path between deployment zones")

# Terrain Effects Tests
func test_terrain_effects() -> void:
	var config = {"mission_type": GameEnums.MissionType.PATROL}
	var battlefield = _instance.generate_battlefield(config)
	
	for feature in battlefield.terrain:
		match feature.type:
			TerrainTypes.Type.COVER_HIGH:
				var modifiers = _terrain_rules.get_feature_modifiers(GameEnums.TerrainFeatureType.OBSTACLE)
				assert_true(GameEnums.TerrainModifier.FULL_COVER in modifiers,
					"High cover should provide full cover")
			
			TerrainTypes.Type.COVER_LOW:
				var modifiers = _terrain_rules.get_feature_modifiers(GameEnums.TerrainFeatureType.COVER)
				assert_true(GameEnums.TerrainModifier.PARTIAL_COVER in modifiers,
					"Low cover should provide partial cover")
			
			TerrainTypes.Type.HAZARD:
				var modifiers = _terrain_rules.get_feature_modifiers(GameEnums.TerrainFeatureType.HAZARD)
				assert_true(GameEnums.TerrainModifier.HAZARDOUS in modifiers,
					"Hazard should be hazardous")
				assert_true(GameEnums.TerrainModifier.MOVEMENT_PENALTY in modifiers,
					"Hazard should penalize movement")
			
			TerrainTypes.Type.DIFFICULT:
				var modifiers = _terrain_rules.get_feature_modifiers(GameEnums.TerrainFeatureType.OBSTACLE)
				assert_true(GameEnums.TerrainModifier.DIFFICULT_TERRAIN in modifiers,
					"Difficult terrain should have movement penalty")

# Environment Type Tests
func test_environment_types() -> void:
	var config = {
		"mission_type": GameEnums.MissionType.PATROL,
		"environment": GameEnums.PlanetEnvironment.URBAN
	}
	var battlefield = _instance.generate_battlefield(config)
	
	# Check that urban environment has appropriate modifiers
	var urban_modifiers = _terrain_rules.get_terrain_modifiers(GameEnums.PlanetEnvironment.URBAN)
	assert_true(GameEnums.TerrainModifier.COVER_BONUS in urban_modifiers,
		"Urban environment should provide cover bonus")
	assert_true(GameEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED in urban_modifiers,
		"Urban environment should affect line of sight")
	
	# Test forest environment
	config.environment = GameEnums.PlanetEnvironment.FOREST
	battlefield = _instance.generate_battlefield(config)
	var forest_modifiers = _terrain_rules.get_terrain_modifiers(GameEnums.PlanetEnvironment.FOREST)
	assert_true(GameEnums.TerrainModifier.DIFFICULT_TERRAIN in forest_modifiers,
		"Forest should be difficult terrain")
	assert_true(GameEnums.TerrainModifier.COVER_BONUS in forest_modifiers,
		"Forest should provide cover bonus")
	
	# Test hazardous environment
	config.environment = GameEnums.PlanetEnvironment.HAZARDOUS
	battlefield = _instance.generate_battlefield(config)
	var hazard_modifiers = _terrain_rules.get_terrain_modifiers(GameEnums.PlanetEnvironment.HAZARDOUS)
	assert_true(GameEnums.TerrainModifier.COVER_BONUS in hazard_modifiers,
		"Hazardous environment should provide cover bonus")
	assert_true(GameEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED in hazard_modifiers,
		"Hazardous environment should affect line of sight")

# Helper Functions
func _get_min_distance_between_zones(zone1: Array, zone2: Array) -> float:
	var min_distance = 999999.0
	for pos1 in zone1:
		for pos2 in zone2:
			var distance = pos1.distance_to(pos2)
			min_distance = min(min_distance, distance)
	return min_distance

# Unit Tests
func test_generate_mission() -> void:
	var mission = _instance.generate_mission()
	if mission is Resource:
		track_test_resource(mission)
	
	assert_not_null(mission, "Mission should be created")
	assert_true(mission.type in GameEnums.MissionType.values(),
		"Mission type should be valid: %s" % GameEnums.MissionType.keys()[mission.type])
	assert_true(mission.difficulty in GameEnums.DifficultyLevel.values(),
		"Difficulty should be valid: %s" % GameEnums.DifficultyLevel.keys()[mission.difficulty])
	assert_true(mission.environment in GameEnums.PlanetEnvironment.values(),
		"Environment should be valid: %s" % GameEnums.PlanetEnvironment.keys()[mission.environment])
	assert_true(mission.objective in GameEnums.MissionObjective.values(),
		"Objective should be valid: %s" % GameEnums.MissionObjective.keys()[mission.objective])

func test_battlefield_size() -> void:
	var mission = _instance.generate_mission()
	if mission is Resource:
		track_test_resource(mission)
	
	var size = _instance.get_battlefield_size(mission)
	assert_true(size.x > 0 and size.y > 0, "Battlefield should have positive dimensions")
	assert_true(size.x <= DEFAULT_MAX_SIZE.x and size.y <= DEFAULT_MAX_SIZE.y,
		"Battlefield should not exceed maximum size")
	assert_true(size.x >= DEFAULT_MIN_SIZE.x and size.y >= DEFAULT_MIN_SIZE.y,
		"Battlefield should meet minimum size requirements")

func test_battlefield_size_by_mission_type() -> void:
	var mission_types = [
		GameEnums.MissionType.SABOTAGE,
		GameEnums.MissionType.RESCUE,
		GameEnums.MissionType.BLACK_ZONE,
		GameEnums.MissionType.GREEN_ZONE,
		GameEnums.MissionType.RED_ZONE,
		GameEnums.MissionType.PATROL
	]
	
	for type in mission_types:
		var mission = _instance.generate_mission()
		mission.type = type
		if mission is Resource:
			track_test_resource(mission)
		
		var size = _instance.get_battlefield_size(mission)
		assert_true(size.x >= DEFAULT_MIN_SIZE.x and size.y >= DEFAULT_MIN_SIZE.y,
			"Mission type %s should have valid minimum size" % GameEnums.MissionType.keys()[type])
		assert_true(size.x <= DEFAULT_MAX_SIZE.x and size.y <= DEFAULT_MAX_SIZE.y,
			"Mission type %s should have valid maximum size" % GameEnums.MissionType.keys()[type])

func test_terrain_feature_placement() -> void:
	var battlefield = _instance.generate_battlefield()
	assert_not_null(battlefield, "Battlefield should be created")
	assert_true(battlefield.has("terrain"), "Battlefield should have terrain data")
	
	# Check that some terrain features were placed
	var has_features = false
	var terrain_data = battlefield.get("terrain", [])
	for row in terrain_data:
		for cell in row.get("row", []):
			if cell.get("type", TerrainTypes.Type.NONE) != TerrainTypes.Type.NONE:
				has_features = true
				break
		if has_features:
			break
	
	assert_true(has_features, "Battlefield should have terrain features")

# Performance Tests
func test_battlefield_generation_performance() -> void:
	var total_time := 0
	var success_count := 0
	
	for i in range(TEST_ITERATIONS):
		var start_time := Time.get_ticks_msec()
		var battlefield := _instance.generate_battlefield()
		var end_time := Time.get_ticks_msec()
		
		if not battlefield.is_empty():
			total_time += (end_time - start_time)
			success_count += 1
	
	var average_time: float = total_time / float(success_count) if success_count > 0 else INF
	assert_lt(average_time, BATTLEFIELD_GEN_THRESHOLD,
		"Battlefield generation should complete within %d ms (got %d ms)" % [
			BATTLEFIELD_GEN_THRESHOLD,
			average_time
		])

func test_terrain_update_performance() -> void:
	var total_time := 0
	var success_count := 0
	var battlefield := _instance.generate_battlefield()
	
	for i in range(TEST_ITERATIONS):
		var start_time := Time.get_ticks_msec()
		
		# Update multiple terrain cells
		for j in range(10):
			var pos := Vector2i(randi() % battlefield.size.x, randi() % battlefield.size.y)
			var terrain_data = battlefield.get("terrain", [])
			if pos.x < terrain_data.size() and pos.y < terrain_data[pos.x].get("row", []).size():
				terrain_data[pos.x]["row"][pos.y]["type"] = TerrainTypes.Type.WALL
		
		var end_time := Time.get_ticks_msec()
		total_time += (end_time - start_time)
		success_count += 1
	
	var average_time: float = total_time / float(success_count) if success_count > 0 else INF
	assert_lt(average_time, TERRAIN_UPDATE_THRESHOLD,
		"Terrain updates should complete within %d ms (got %d ms)" % [
			TERRAIN_UPDATE_THRESHOLD,
			average_time
		])

func test_performance_large_battlefield_generation() -> void:
	var start_time := Time.get_ticks_msec()
	var battlefield := _generate_large_battlefield()
	var duration := Time.get_ticks_msec() - start_time
	
	assert_true(duration < BATTLEFIELD_GEN_THRESHOLD,
		"Large battlefield generation should complete within %d ms" % BATTLEFIELD_GEN_THRESHOLD)
	assert_not_null(battlefield)

# Boundary Tests
func test_boundary_minimum_size() -> void:
	var battlefield := _instance.generate_battlefield({"size": Vector2i(1, 1)})
	assert_true(battlefield.size >= DEFAULT_MIN_SIZE,
		"Battlefield should enforce minimum size")

func test_boundary_maximum_size() -> void:
	var battlefield := _instance.generate_battlefield({"size": Vector2i(1000, 1000)})
	assert_true(battlefield.size <= DEFAULT_MAX_SIZE,
		"Battlefield should enforce maximum size")

# Signal Tests
func test_signals_generation_started() -> void:
	_signal_received = false
	_instance.generation_started.connect(_on_generation_started)
	_instance.generate_battlefield({"size": DEFAULT_MIN_SIZE})
	assert_true(_signal_received, "Generation started signal should be emitted")

func test_signals_generation_completed() -> void:
	_signal_received = false
	_instance.generation_completed.connect(_on_generation_completed)
	_instance.generate_battlefield({"size": DEFAULT_MIN_SIZE})
	assert_true(_signal_received, "Generation completed signal should be emitted")

# Error Tests
func test_error_invalid_mission_type() -> void:
	var mission = _create_test_mission(-1)
	assert_null(_instance.generate_battlefield_for_mission(mission),
		"Invalid mission type should return null")

# Signal Handlers
func _on_generation_started() -> void:
	_signal_received = true

func _on_generation_completed() -> void:
	_signal_received = true