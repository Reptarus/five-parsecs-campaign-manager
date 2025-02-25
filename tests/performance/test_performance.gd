@tool
extends "res://tests/fixtures/base/base_test.gd"

# Required type declarations
const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const BattlefieldGeneratorScript: GDScript = preload("res://src/core/battle/BattlefieldGenerator.gd")
const BattlefieldManagerScript: GDScript = preload("res://src/core/battle/BattlefieldManager.gd")
const TerrainTypesScript: GDScript = preload("res://src/core/terrain/TerrainTypes.gd")
const TypeSafeMixin: GDScript = preload("res://tests/fixtures/helpers/type_safe_test_mixin.gd")

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
		
		var battlefield: Node = TypeSafeMixin._safe_method_call_node(battlefield_generator, "generate_battlefield", [config])
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
	
	var battlefield: Node = TypeSafeMixin._safe_method_call_node(battlefield_generator, "generate_battlefield", [config])
	assert_not_null(battlefield, "Should generate battlefield")
	
	var total_time: int = 0
	
	for i in TEST_ITERATIONS:
		var start_time: int = Time.get_ticks_msec()
		
		# Update terrain
		TypeSafeMixin._safe_method_call_bool(battlefield_manager, "update_terrain", [battlefield])
		
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
	
	var battlefield: Node = TypeSafeMixin._safe_method_call_node(battlefield_generator, "generate_battlefield", [config])
	assert_not_null(battlefield, "Should generate battlefield")
	
	var total_time: int = 0
	var start_pos := Vector2(2, 2)
	var end_pos := Vector2(22, 22)
	
	for i in TEST_ITERATIONS:
		var start_time: int = Time.get_ticks_msec()
		
		# Check line of sight
		TypeSafeMixin._safe_method_call_bool(battlefield_manager, "has_line_of_sight", [
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
	
	var battlefield: Node = TypeSafeMixin._safe_method_call_node(battlefield_generator, "generate_battlefield", [config])
	assert_not_null(battlefield, "Should generate battlefield")
	
	var total_time: int = 0
	var start_pos := Vector2(2, 2)
	var end_pos := Vector2(22, 22)
	
	for i in TEST_ITERATIONS:
		var start_time: int = Time.get_ticks_msec()
		
		# Find path
		var path: Array = TypeSafeMixin._safe_method_call_array(battlefield_manager, "find_path", [
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
		
		var battlefield: Node = TypeSafeMixin._safe_method_call_node(battlefield_generator, "generate_battlefield", [config])
		assert_not_null(battlefield, "Should generate battlefield")
		
		var current_memory: int = OS.get_static_memory_usage()
		peak_memory = max(peak_memory, current_memory)
		
		if is_instance_valid(battlefield):
			battlefield.queue_free()
		await get_tree().create_timer(CLEANUP_DELAY_MS / 1000.0).timeout
	
	var memory_increase: float = (peak_memory - start_memory) / 1024.0 / 1024.0 # Convert to MB
	assert_lt(memory_increase, MEMORY_THRESHOLD_MB,
		"Memory usage increase should be within threshold")