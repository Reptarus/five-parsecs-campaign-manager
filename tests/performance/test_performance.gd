@tool
extends "res://tests/fixtures/game_test.gd"

const BattlefieldGenerator := preload("res://src/core/battle/BattlefieldGenerator.gd")
const BattlefieldManager := preload("res://src/core/battle/BattlefieldManager.gd")
const TerrainTypes := preload("res://src/core/terrain/TerrainTypes.gd")

var battlefield_generator: BattlefieldGenerator = null
var battlefield_manager: BattlefieldManager = null

const BATTLEFIELD_GEN_THRESHOLD := 100
const TERRAIN_UPDATE_THRESHOLD := 50
const LINE_OF_SIGHT_THRESHOLD := 16
const PATHFINDING_THRESHOLD := 100

const TEST_ITERATIONS := 10
const MEMORY_TEST_ITERATIONS := 50
const MEMORY_THRESHOLD_MB := 10
const CLEANUP_DELAY_MS := 100

func before_all() -> void:
	super.before_all()

func after_all() -> void:
	super.after_all()

func before_each() -> void:
	await super.before_each()
	
	# Initialize battlefield systems
	battlefield_generator = BattlefieldGenerator.new()
	add_child_autofree(battlefield_generator)
	track_test_node(battlefield_generator)
	
	battlefield_manager = BattlefieldManager.new()
	add_child_autofree(battlefield_manager)
	track_test_node(battlefield_manager)
	
	await stabilize_engine()

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
	
	# Clear any tracked resources
	_tracked_resources.clear()

func test_battlefield_generation_performance() -> void:
	var total_time := 0
	var total_memory := 0
	
	for i in TEST_ITERATIONS:
		var start_time = Time.get_ticks_msec()
		var start_memory = OS.get_static_memory_usage()
		
		# Generate battlefield with test config
		var config = {
			"size": Vector2i(24, 24),
			"battlefield_type": GameEnums.PlanetEnvironment.URBAN,
			"environment": GameEnums.PlanetEnvironment.URBAN,
			"cover_density": 0.2,
			"symmetrical": true,
			"deployment_zone_size": 6,
			"objective_count": 1
		}
		var battlefield = battlefield_generator.generate_battlefield(config)
		assert_not_null(battlefield, "Battlefield should be generated")
		
		# Calculate metrics
		var generation_time = Time.get_ticks_msec() - start_time
		var memory_used = OS.get_static_memory_usage() - start_memory
		
		total_time += generation_time
		total_memory += memory_used
		
		await get_tree().process_frame
	
	var average_time = total_time / TEST_ITERATIONS
	var average_memory = total_memory / TEST_ITERATIONS
	
	assert_true(average_time < BATTLEFIELD_GEN_THRESHOLD,
		"Average generation time (%d ms) should be under threshold" % average_time)
	assert_true(average_memory < MEMORY_THRESHOLD_MB * 1024 * 1024,
		"Average memory usage (%d bytes) should be under threshold" % average_memory)

func test_terrain_update_performance() -> void:
	var total_time := 0
	
	for i in TEST_ITERATIONS:
		var start_time = Time.get_ticks_msec()
		
		# Update terrain
		battlefield_manager.update_terrain()
		
		# Calculate metrics
		var update_time = Time.get_ticks_msec() - start_time
		total_time += update_time
		
		await get_tree().process_frame
	
	var average_time = total_time / TEST_ITERATIONS
	
	assert_true(average_time < TERRAIN_UPDATE_THRESHOLD,
		"Average update time (%d ms) should be under threshold" % average_time)

func test_line_of_sight_performance() -> void:
	var total_time := 0
	
	for i in TEST_ITERATIONS:
		var start_time = Time.get_ticks_msec()
		
		# Check line of sight between random points
		var start = Vector2(randf_range(0, 10), randf_range(0, 10))
		var end = Vector2(randf_range(0, 10), randf_range(0, 10))
		var has_los = battlefield_manager.check_line_of_sight(start, end)
		
		# Calculate metrics
		var check_time = Time.get_ticks_msec() - start_time
		total_time += check_time
		
		await get_tree().process_frame
	
	var average_time = total_time / TEST_ITERATIONS
	
	assert_true(average_time < LINE_OF_SIGHT_THRESHOLD,
		"Average line of sight check time (%d ms) should be under threshold" % average_time)

func test_pathfinding_performance() -> void:
	var total_time := 0
	
	for i in TEST_ITERATIONS:
		var start_time = Time.get_ticks_msec()
		
		# Find path between random points
		var start = Vector2(randf_range(0, 10), randf_range(0, 10))
		var end = Vector2(randf_range(0, 10), randf_range(0, 10))
		var path = battlefield_manager.find_path(start, end)
		
		# Calculate metrics
		var pathfinding_time = Time.get_ticks_msec() - start_time
		total_time += pathfinding_time
		
		await get_tree().process_frame
	
	var average_time = total_time / TEST_ITERATIONS
	
	assert_true(average_time < PATHFINDING_THRESHOLD,
		"Average pathfinding time (%d ms) should be under threshold" % average_time)

# Memory Usage Tests
func test_memory_usage() -> void:
	var initial_memory := OS.get_static_memory_usage()
	
	# Perform memory-intensive operations
	for i in range(MEMORY_TEST_ITERATIONS):
		var battlefield := battlefield_generator.generate_battlefield()
		# Let the battlefield go out of scope naturally
	
	# Force garbage collection
	OS.delay_msec(CLEANUP_DELAY_MS)
	
	var final_memory := OS.get_static_memory_usage()
	var memory_increase := final_memory - initial_memory
	
	assert_lt(memory_increase, MEMORY_THRESHOLD_MB * 1024 * 1024,
		"Memory usage increase should be less than %dMB (got %.2f MB)" % [
			MEMORY_THRESHOLD_MB,
			memory_increase / (1024.0 * 1024.0)
		])