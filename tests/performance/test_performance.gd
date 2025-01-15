extends "res://addons/gut/test.gd"

const BattlefieldGenerator := preload("res://src/core/battle/BattlefieldGenerator.gd")
const BattlefieldManager := preload("res://src/core/battle/BattlefieldManager.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const TerrainTypes := preload("res://src/core/terrain/TerrainTypes.gd")

# Test variables
var battlefield_generator: BattlefieldGenerator
var battlefield_manager: BattlefieldManager

# Performance thresholds (in milliseconds)
const BATTLEFIELD_GEN_THRESHOLD := 100
const TERRAIN_UPDATE_THRESHOLD := 50
const LINE_OF_SIGHT_THRESHOLD := 16
const PATHFINDING_THRESHOLD := 100

# Test configuration
const TEST_ITERATIONS := 10
const MEMORY_TEST_ITERATIONS := 50
const MEMORY_THRESHOLD_MB := 10 # 10MB
const CLEANUP_DELAY_MS := 100

func before_all() -> void:
    super.before_all()
    battlefield_generator = BattlefieldGenerator.new()
    battlefield_manager = BattlefieldManager.new()
    add_child(battlefield_generator)
    add_child(battlefield_manager)

func after_all() -> void:
    super.after_all()
    battlefield_generator.queue_free()
    battlefield_manager.queue_free()

# Battlefield Generation Performance Tests
func test_battlefield_generation_performance() -> void:
    var total_time := 0
    var success_count := 0
    
    for i in range(TEST_ITERATIONS):
        var start_time := Time.get_ticks_msec()
        var battlefield := battlefield_generator.generate_battlefield()
        var end_time := Time.get_ticks_msec()
        
        if battlefield:
            total_time += (end_time - start_time)
            success_count += 1
    
    var average_time: float = total_time / float(success_count) if success_count > 0 else INF
    assert_lt(average_time, BATTLEFIELD_GEN_THRESHOLD,
        "Battlefield generation should complete within %d ms (got %d ms)" % [
            BATTLEFIELD_GEN_THRESHOLD,
            average_time
        ])

# Terrain Update Performance Tests
func test_terrain_update_performance() -> void:
    var total_time := 0
    var success_count := 0
    var battlefield := battlefield_generator.generate_battlefield()
    
    for i in range(TEST_ITERATIONS):
        var start_time := Time.get_ticks_msec()
        
        # Update multiple terrain cells
        for j in range(10):
            var pos := Vector2i(randi() % battlefield.size.x, randi() % battlefield.size.y)
            var terrain_type: int = TerrainTypes.Type.WALL
            battlefield_manager.set_terrain(pos, terrain_type)
        
        var end_time := Time.get_ticks_msec()
        total_time += (end_time - start_time)
        success_count += 1
    
    var average_time: float = total_time / float(success_count) if success_count > 0 else INF
    assert_lt(average_time, TERRAIN_UPDATE_THRESHOLD,
        "Terrain updates should complete within %d ms (got %d ms)" % [
            TERRAIN_UPDATE_THRESHOLD,
            average_time
        ])

# Line of Sight Performance Tests
func test_line_of_sight_performance() -> void:
    var total_time := 0
    var success_count := 0
    var battlefield := battlefield_generator.generate_battlefield()
    
    for i in range(TEST_ITERATIONS):
        var start_time := Time.get_ticks_msec()
        
        # Test multiple line of sight calculations
        for j in range(10):
            var from_pos := Vector2i(randi() % battlefield.size.x, randi() % battlefield.size.y)
            var to_pos := Vector2i(randi() % battlefield.size.x, randi() % battlefield.size.y)
            battlefield_manager.has_line_of_sight(from_pos, to_pos)
        
        var end_time := Time.get_ticks_msec()
        total_time += (end_time - start_time)
        success_count += 1
    
    var average_time: float = total_time / float(success_count) if success_count > 0 else INF
    assert_lt(average_time, LINE_OF_SIGHT_THRESHOLD,
        "Line of sight calculations should complete within %d ms (got %d ms)" % [
            LINE_OF_SIGHT_THRESHOLD,
            average_time
        ])

# Pathfinding Performance Tests
func test_pathfinding_performance() -> void:
    var total_time := 0
    var success_count := 0
    var battlefield := battlefield_generator.generate_battlefield()
    
    for i in range(TEST_ITERATIONS):
        var start_time := Time.get_ticks_msec()
        
        # Test multiple pathfinding calculations
        for j in range(5):
            var from_pos := Vector2i(randi() % battlefield.size.x, randi() % battlefield.size.y)
            var to_pos := Vector2i(randi() % battlefield.size.x, randi() % battlefield.size.y)
            battlefield_manager._find_path(from_pos, to_pos)
        
        var end_time := Time.get_ticks_msec()
        total_time += (end_time - start_time)
        success_count += 1
    
    var average_time: float = total_time / float(success_count) if success_count > 0 else INF
    assert_lt(average_time, PATHFINDING_THRESHOLD,
        "Pathfinding calculations should complete within %d ms (got %d ms)" % [
            PATHFINDING_THRESHOLD,
            average_time
        ])

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