@tool
extends "res://tests/fixtures/base/base_test.gd"

# Required type declarations
const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const BattlefieldGeneratorScript: GDScript = preload("res://src/core/systems/BattlefieldGenerator.gd")
const BattlefieldManagerScript: GDScript = preload("res://src/base/combat/battlefield/BaseBattlefieldManager.gd")
const TerrainTypesScript: GDScript = preload("res://src/core/terrain/TerrainTypes.gd")

# Performance thresholds with explicit types
const BATTLEFIELD_GEN_THRESHOLD: int = 100
const TERRAIN_UPDATE_THRESHOLD: int = 50
const LINE_OF_SIGHT_THRESHOLD: int = 16
const PATHFINDING_THRESHOLD: int = 100

const TEST_ITERATIONS: int = 10
const MEMORY_TEST_ITERATIONS: int = 50
const MEMORY_THRESHOLD_MB: int = 10
const CLEANUP_DELAY_MS: int = 100

# Test variables with explicit types
var battlefield_generator: Node = null
var battlefield_manager: Node = null

func before_all() -> void:
	await super.before_all()

func after_all() -> void:
	await super.after_all()

func before_each() -> void:
	await super.before_each()
	
	# Initialize battlefield systems
	battlefield_generator = TypeSafeMixin._safe_cast_to_node(BattlefieldGeneratorScript.new(), "BattlefieldGenerator")
	if not battlefield_generator:
		push_error("Failed to create battlefield generator")
		return
		
	add_child(battlefield_generator)
	
	battlefield_manager = TypeSafeMixin._safe_cast_to_node(BattlefieldManagerScript.new(), "BattlefieldManager")
	if not battlefield_manager:
		push_error("Failed to create battlefield manager")
		return
		
	add_child(battlefield_manager)
	
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	# Clean up nodes first
	if is_instance_valid(battlefield_generator):
		remove_child(battlefield_generator)
		battlefield_generator.queue_free()
	
	if is_instance_valid(battlefield_manager):
		remove_child(battlefield_manager)
		battlefield_manager.queue_free()
	
	# Wait for nodes to be freed
	await get_tree().process_frame
	
	# Clear references
	battlefield_generator = null
	battlefield_manager = null
	
	# Let parent handle remaining cleanup
	await super.after_each()

func test_battlefield_generation_performance() -> void:
	var total_time: int = 0
	var total_memory: int = 0
	
	for i in TEST_ITERATIONS:
		var start_time: int = Time.get_ticks_msec()
		var start_memory: int = OS.get_static_memory_usage()
		
		# Generate battlefield with test config
		var config: Dictionary = {
			"size": Vector2i(24, 24),
			"battlefield_type": GameEnums.PlanetEnvironment.URBAN,
			"environment": GameEnums.PlanetEnvironment.URBAN,
			"cover_density": 0.2,
			"symmetrical": true,
			"deployment_zone_size": 6,
			"objective_count": 1
		}
		
		var battlefield: Node = TypeSafeMixin._safe_cast_to_node(TypeSafeMixin._call_node_method(battlefield_generator, "generate_battlefield", [config]))
		assert_not_null(battlefield, "Should generate battlefield")
		
		var end_time: int = Time.get_ticks_msec()
		var end_memory: int = OS.get_static_memory_usage()
		
		total_time += end_time - start_time
		total_memory += end_memory - start_memory
		
		# Clean up
		if is_instance_valid(battlefield):
			battlefield.queue_free()
		await get_tree().create_timer(CLEANUP_DELAY_MS / 1000.0).timeout
	
	var average_time: float = total_time / float(TEST_ITERATIONS)
	var average_memory: float = total_memory / float(TEST_ITERATIONS) / 1024.0 / 1024.0 # Convert to MB
	
	assert_lt(average_time, BATTLEFIELD_GEN_THRESHOLD,
		"Battlefield generation should complete within threshold")
	assert_lt(average_memory, MEMORY_THRESHOLD_MB,
		"Memory usage should be within threshold")

func test_terrain_update_performance() -> void:
	var config: Dictionary = {
		"size": Vector2i(24, 24),
		"battlefield_type": GameEnums.PlanetEnvironment.URBAN,
		"environment": GameEnums.PlanetEnvironment.URBAN,
		"cover_density": 0.2,
		"symmetrical": true,
		"deployment_zone_size": 6,
		"objective_count": 1
	}
	
	var battlefield: Node = TypeSafeMixin._safe_cast_to_node(TypeSafeMixin._call_node_method(battlefield_generator, "generate_battlefield", [config]))
	assert_not_null(battlefield, "Should generate battlefield")
	
	var total_time: int = 0
	
	for i in TEST_ITERATIONS:
		var start_time: int = Time.get_ticks_msec()
		
		# Update terrain
		TypeSafeMixin._call_node_method_bool(battlefield_manager, "update_terrain", [battlefield])
		
		var end_time: int = Time.get_ticks_msec()
		total_time += end_time - start_time
	
	var average_time: float = total_time / float(TEST_ITERATIONS)
	
	assert_lt(average_time, TERRAIN_UPDATE_THRESHOLD,
		"Terrain updates should complete within threshold")
	
	if is_instance_valid(battlefield):
		battlefield.queue_free()

func test_line_of_sight_performance() -> void:
	var config: Dictionary = {
		"size": Vector2i(24, 24),
		"battlefield_type": GameEnums.PlanetEnvironment.URBAN,
		"environment": GameEnums.PlanetEnvironment.URBAN,
		"cover_density": 0.2,
		"symmetrical": true,
		"deployment_zone_size": 6,
		"objective_count": 1
	}
	
	var battlefield: Node = TypeSafeMixin._safe_cast_to_node(TypeSafeMixin._call_node_method(battlefield_generator, "generate_battlefield", [config]))
	assert_not_null(battlefield, "Should generate battlefield")
	
	var total_time: int = 0
	var start_pos := Vector2(2, 2)
	var end_pos := Vector2(22, 22)
	
	for i in TEST_ITERATIONS:
		var start_time: int = Time.get_ticks_msec()
		
		# Check line of sight
		TypeSafeMixin._call_node_method_bool(battlefield_manager, "has_line_of_sight", [
			battlefield,
			start_pos,
			end_pos
		])
		
		var end_time: int = Time.get_ticks_msec()
		total_time += end_time - start_time
	
	var average_time: float = total_time / float(TEST_ITERATIONS)
	
	assert_lt(average_time, LINE_OF_SIGHT_THRESHOLD,
		"Line of sight checks should complete within threshold")
	
	if is_instance_valid(battlefield):
		battlefield.queue_free()

func test_pathfinding_performance() -> void:
	var config: Dictionary = {
		"size": Vector2i(24, 24),
		"battlefield_type": GameEnums.PlanetEnvironment.URBAN,
		"environment": GameEnums.PlanetEnvironment.URBAN,
		"cover_density": 0.2,
		"symmetrical": true,
		"deployment_zone_size": 6,
		"objective_count": 1
	}
	
	var battlefield: Node = TypeSafeMixin._safe_cast_to_node(TypeSafeMixin._call_node_method(battlefield_generator, "generate_battlefield", [config]))
	assert_not_null(battlefield, "Should generate battlefield")
	
	var total_time: int = 0
	var start_pos := Vector2(2, 2)
	var end_pos := Vector2(22, 22)
	
	for i in TEST_ITERATIONS:
		var start_time: int = Time.get_ticks_msec()
		
		# Find path
		var path: Array = TypeSafeMixin._call_node_method_array(battlefield_manager, "find_path", [
			battlefield,
			start_pos,
			end_pos
		])
		assert_not_null(path, "Should find path")
		
		var end_time: int = Time.get_ticks_msec()
		total_time += end_time - start_time
	
	var average_time: float = total_time / float(TEST_ITERATIONS)
	
	assert_lt(average_time, PATHFINDING_THRESHOLD,
		"Pathfinding should complete within threshold")
	
	if is_instance_valid(battlefield):
		battlefield.queue_free()

func test_memory_usage() -> void:
	var start_memory: int = OS.get_static_memory_usage()
	var peak_memory: int = start_memory
	
	for i in MEMORY_TEST_ITERATIONS:
		var config: Dictionary = {
			"size": Vector2i(24, 24),
			"battlefield_type": GameEnums.PlanetEnvironment.URBAN,
			"environment": GameEnums.PlanetEnvironment.URBAN,
			"cover_density": 0.2,
			"symmetrical": true,
			"deployment_zone_size": 6,
			"objective_count": 1
		}
		
		var battlefield: Node = TypeSafeMixin._safe_cast_to_node(TypeSafeMixin._call_node_method(battlefield_generator, "generate_battlefield", [config]))
		assert_not_null(battlefield, "Should generate battlefield")
		
		var current_memory: int = OS.get_static_memory_usage()
		peak_memory = max(peak_memory, current_memory)
		
		if is_instance_valid(battlefield):
			battlefield.queue_free()
		await get_tree().create_timer(CLEANUP_DELAY_MS / 1000.0).timeout
	
	var memory_increase: float = (peak_memory - start_memory) / 1024.0 / 1024.0 # Convert to MB
	assert_lt(memory_increase, MEMORY_THRESHOLD_MB,
		"Memory usage increase should be within threshold")

# Battlefield Methods
func create_empty_battlefield(size: Vector2i = Vector2i(10, 10)) -> Node:
	var battlefield_manager = BattlefieldManagerScript.new()
	if not battlefield_manager:
		push_error("Failed to create battlefield manager")
		return null
		
	var battlefield: Node = TypeSafeMixin._safe_cast_to_node(TypeSafeMixin._call_node_method(battlefield_manager, "create_battlefield", [size]))
	if not battlefield:
		push_error("Failed to create battlefield")
		return null
		
	add_child_autofree(battlefield_manager)
	track_test_node(battlefield_manager)
	track_test_node(battlefield)
	return battlefield

func populate_battlefield(battlefield: Node, unit_count: int) -> void:
	if not battlefield:
		push_error("Cannot populate null battlefield")
		return
		
	for i in range(unit_count):
		var unit_node: Node = Node.new()
		unit_node.name = "TestUnit%d" % i
		if not unit_node:
			push_error("Failed to create test unit")
			continue
			
		var unit: Node = TypeSafeMixin._safe_cast_to_node(TypeSafeMixin._call_node_method(battlefield, "add_unit", [unit_node, Vector2i(i % 10, i / 10)]))
		if not unit:
			push_error("Failed to add unit to battlefield")
			continue
			
		TypeSafeMixin._call_node_method_bool(unit, "set_team", [i % 2])
		track_test_node(unit)

func create_unit_array(count: int) -> Array:
	var units := []
	for i in range(count):
		var unit: Node = Node.new()
		unit.name = "TestUnit%d" % i
		if not unit:
			push_error("Failed to create test unit")
			continue
			
		var battlefield_unit: Node = TypeSafeMixin._safe_cast_to_node(TypeSafeMixin._call_node_method(unit, "initialize", []))
		if not battlefield_unit:
			push_error("Failed to initialize battlefield unit")
			continue
			
		add_child_autofree(battlefield_unit)
		track_test_node(battlefield_unit)
		units.append(battlefield_unit)
	return units

# Terrain Methods
func create_test_terrain(type: int = 0) -> Node:
	var terrain_system = TerrainTypesScript.new()
	if not terrain_system:
		push_error("Failed to create terrain system")
		return null
		
	var terrain: Node = TypeSafeMixin._safe_cast_to_node(TypeSafeMixin._call_node_method(terrain_system, "create_terrain", [type]))
	if not terrain:
		push_error("Failed to create terrain")
		return null
		
	add_child_autofree(terrain_system)
	track_test_node(terrain_system)
	track_test_node(terrain)
	return terrain

func populate_terrain(terrain: Node, feature_count: int) -> void:
	if not terrain:
		push_error("Cannot populate null terrain")
		return
		
	for i in range(feature_count):
		var terrain_feature: Array = TypeSafeMixin._call_node_method_array(terrain, "get_available_features", [])
		if terrain_feature.is_empty():
			push_error("No available features")
			continue
			
		TypeSafeMixin._call_node_method_bool(terrain, "add_feature", [terrain_feature[0], Vector2i(i % 10, i / 10)])

# Pathfinding Methods
func create_test_pathfinding_grid(size: Vector2i = Vector2i(10, 10)) -> Node:
	var battlefield = create_empty_battlefield(size)
	if not battlefield:
		push_error("Failed to create battlefield for pathfinding")
		return null
		
	var pathfinding: Node = TypeSafeMixin._safe_cast_to_node(TypeSafeMixin._call_node_method(battlefield, "get_pathfinding", []))
	if not pathfinding:
		push_error("Failed to get pathfinding from battlefield")
		return null
		
	return pathfinding