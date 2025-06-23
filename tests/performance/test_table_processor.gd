@tool
extends GdUnitGameTest

# Table processor performance test constants
const TableProcessorScript: GDScript = preload("res://src/core/systems/TableProcessor.gd")
const TableLoaderScript: GDScript = preload("res://src/core/systems/TableLoader.gd")

# Test variables with explicit types
var _processor: Node = null
var _test_tables: Array[Dictionary] = []
var _data_manager: Node = null

# Table size configurations
const TABLE_SIZES := {
    "small": {
        "rows": 100,
        "columns": 5,
    },
    "medium": {
        "rows": 1000,
        "columns": 10,
    },
    "large": {
        "rows": 10000,
        "columns": 20,
    }
}

# Performance thresholds for different table sizes
const TABLE_THRESHOLDS := {
    "small": {
        "average_fps": 55.0,
        "minimum_fps": 45.0,
        "memory_delta_kb": 128.0,
        "processing_time_ms": 16.0,
    },
    "medium": {
        "average_fps": 45.0,
        "minimum_fps": 35.0,
        "memory_delta_kb": 512.0,
        "processing_time_ms": 33.0,
    },
    "large": {
        "average_fps": 35.0,
        "minimum_fps": 25.0,
        "memory_delta_kb": 2048.0,
        "processing_time_ms": 66.0,
    }
}

const STABILIZE_TIME := 0.1

# Helper method for safe method calls
func _safe_call_method_bool(node: Node, method_name: String, args: Array = []) -> bool:
    if node and node.has_method(method_name):
        return node.callv(method_name, args)
    return false

func before_test() -> void:
    super.before_test()
    await get_tree().process_frame
    
    # Create processor instance
    _processor = TableProcessorScript.new()
    if not _processor:
        _processor = Node.new()
    
    _processor = auto_free(_processor)
    
    # Create data manager
    _data_manager = auto_free(Node.new())
    _data_manager.name = "TestDataManager"

func after_test() -> void:
    # Clean up test tables
    _test_tables.clear()
    
    if is_instance_valid(_processor):
        _processor.queue_free()
        _processor = null
    
    if is_instance_valid(_data_manager):
        _data_manager.queue_free()
        _data_manager = null
    
    super.after_test()

func test_small_table_performance() -> void:
    print_debug("Testing small table processing performance...")
    await _setup_test_table("small")
    
    var metrics = await measure_performance(
        func() -> void:
            _safe_call_method_bool(_processor, "process_table", [_test_tables[0]])
            await get_tree().process_frame
    )
    
    verify_performance_metrics(metrics, TABLE_THRESHOLDS.small)

func test_medium_table_performance() -> void:
    print_debug("Testing medium table processing performance...")
    await _setup_test_table("medium")
    
    var metrics = await measure_performance(
        func() -> void:
            _safe_call_method_bool(_processor, "process_table", [_test_tables[0]])
            await get_tree().process_frame
    )
    
    verify_performance_metrics(metrics, TABLE_THRESHOLDS.medium)

func test_large_table_performance() -> void:
    print_debug("Testing large table processing performance...")
    await _setup_test_table("large")
    
    var metrics = await measure_performance(
        func() -> void:
            _safe_call_method_bool(_processor, "process_table", [_test_tables[0]])
            await get_tree().process_frame
    )
    
    verify_performance_metrics(metrics, TABLE_THRESHOLDS.large)

func test_table_memory_management() -> void:
    print_debug("Testing table memory management...")
    
    var initial_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    
    # Test each table size
    for size in TABLE_SIZES.keys():
        await _setup_test_table(size)
        
        # Process table multiple times
        for i: int in range(5):
            _safe_call_method_bool(_processor, "process_table", [_test_tables[0]])
            await get_tree().process_frame
        
        # Clear test data
        _test_tables.clear()
    
    var final_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    var memory_delta := (final_memory - initial_memory) / 1024.0 # KB
    
    assert_that(memory_delta).with_message(
        "Memory should be properly cleaned up after table processing"
    ).is_less(50.0) # 50KB threshold

func test_table_stress() -> void:
    print_debug("Running table processing stress test...")
    
    # Setup medium table
    await _setup_test_table("medium")
    
    stress_test(
        func() -> void:
            # Randomly modify table data during processing
            if randf() < 0.2: # 20% chance each frame
                var modification = randi() % 3
                match modification:
                    0: # Add row
                        _add_test_row(_test_tables[0])
                    1: # Remove row
                        _remove_random_row(_test_tables[0])
                    2: # Modify values
                        _modify_random_values(_test_tables[0])
    )

func test_mobile_table_performance() -> void:
    var _is_mobile = OS.has_feature("mobile")
    if not _is_mobile:
        print_debug("Mobile performance test skipped on non-mobile platform")
        return
    
    # Setup small table (mobile optimized)
    await _setup_test_table("small")
    
    var metrics = await measure_performance(
        func() -> void:
            _safe_call_method_bool(_processor, "process_table", [_test_tables[0]])
            await get_tree().process_frame
    )
    
    # Use mobile-specific thresholds
    var mobile_thresholds := {
        "average_fps": 30.0,
        "minimum_fps": 24.0,
        "memory_delta_kb": 25.0 * 1024,
        "draw_calls_delta": 50,
    }
    verify_performance_metrics(metrics, mobile_thresholds)

# Performance measurement helpers
func measure_performance(callable: Callable, iterations: int = 100) -> Dictionary:
    var results := {
        "fps_samples": [],
        "memory_samples": [],
        "draw_calls": [],
    }
    
    for i: int in range(iterations):
        callable.call()
        await get_tree().process_frame
        
        results.fps_samples.append(Engine.get_frames_per_second())
        results.memory_samples.append(Performance.get_monitor(Performance.MEMORY_STATIC))
        results.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    
    return {
        "average_fps": _calculate_average(results.fps_samples),
        "minimum_fps": _calculate_minimum(results.fps_samples),
        "memory_delta_kb": (_calculate_maximum(results.memory_samples) - _calculate_minimum(results.memory_samples)) / 1024.0,
        "draw_calls_delta": _calculate_maximum(results.draw_calls) - _calculate_minimum(results.draw_calls),
    }

func verify_performance_metrics(metrics: Dictionary, thresholds: Dictionary) -> void:
    assert_that(metrics.get("average_fps", 0.0)).with_message(
        "Average FPS should be above threshold"
    ).is_greater(thresholds.get("average_fps", 30.0))
    
    assert_that(metrics.get("minimum_fps", 0.0)).with_message(
        "Minimum FPS should be above threshold"
    ).is_greater(thresholds.get("minimum_fps", 20.0))
    
    assert_that(metrics.get("memory_delta_kb", 0.0)).with_message(
        "Memory delta should be below threshold"
    ).is_less(thresholds.get("memory_delta_kb", 1024.0))

func stress_test(callable: Callable) -> void:
    var start_time := Time.get_ticks_msec()
    var end_time := start_time + 5000 # 5 seconds
    
    while Time.get_ticks_msec() < end_time:
        callable.call()
        await get_tree().process_frame

# Calculation helpers
func _calculate_average(values: Array) -> float:
    if values.is_empty():
        return 0.0
    
    var sum = 0.0
    for value in values:
        sum += value
    return sum / values.size()

func _calculate_minimum(values: Array) -> float:
    if values.is_empty():
        return 0.0
    
    var min_value = values[0]
    for value in values:
        min_value = min(min_value, value)
    return min_value

func _calculate_maximum(values: Array) -> float:
    if values.is_empty():
        return 0.0
    
    var max_value = values[0]
    for value in values:
        max_value = max(max_value, value)
    return max_value

# Test data generation helpers
func _setup_test_table(size_key: String) -> void:
    var config: Dictionary = TABLE_SIZES[size_key] if TABLE_SIZES.has(size_key) else TABLE_SIZES.small
    
    var table := {
        "rows": [],
        "columns": _generate_test_columns(config.columns),
    }
    
    for i: int in range(config.rows):
        table.rows.append(_generate_test_row(config.columns))
    
    _test_tables.append(table)
    await get_tree().process_frame

func _generate_test_columns(count: int) -> Array[Dictionary]:
    var columns: Array[Dictionary] = []
    for i: int in range(count):
        columns.append({
            "name": "Column_%d" % i,
            "type": "string" if i % 2 == 0 else "number",
        })
    return columns

func _generate_test_row(column_count: int) -> Dictionary:
    var row := {}
    for i: int in range(column_count):
        if i % 2 == 0:
            row["Column_%d" % i] = "Value_%d" % randi()
        else:
            row["Column_%d" % i] = randi() % 100
    return row

func _add_test_row(table: Dictionary) -> void:
    if not table.has("columns") or not table.has("rows"):
        return
    
    var new_row = _generate_test_row(table.columns.size())
    table.rows.append(new_row)

func _remove_random_row(table: Dictionary) -> void:
    if not table.has("rows") or table.rows.is_empty():
        return
    
    var index = randi() % table.rows.size()
    table.rows.remove_at(index)

func _modify_random_values(table: Dictionary) -> void:
    if not table.has("rows") or table.rows.is_empty():
        return
    
    var row_index = randi() % table.rows.size()
    var row = table.rows[row_index]
    
    for column in table.columns:
        if randf() < 0.5: # 50% chance to modify each value
            var column_name = column.name
            if column.type == "string":
                row[column_name] = "Modified_%d" % randi()
            else:
                row[column_name] = randi() % 100
              