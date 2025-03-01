@tool
extends "res://tests/performance/base/perf_test_base.gd"

# Type-safe script references
const TableProcessorScript: GDScript = preload("res://src/core/systems/TableProcessor.gd")
const TableLoaderScript: GDScript = preload("res://src/core/systems/TableLoader.gd")

# Test variables with explicit types
var _processor: Node = null
var _test_tables: Array[Dictionary] = []

# Table size thresholds
const TABLE_SIZES := {
	"small": {
		"rows": 100,
		"columns": 5
	},
	"medium": {
		"rows": 1000,
		"columns": 10
	},
	"large": {
		"rows": 10000,
		"columns": 20
	}
}

# Performance thresholds for different table sizes
const TABLE_THRESHOLDS := {
	"small": {
		"average_fps": 55.0,
		"minimum_fps": 45.0,
		"memory_delta_kb": 128.0,
		"processing_time_ms": 16.0
	},
	"medium": {
		"average_fps": 45.0,
		"minimum_fps": 35.0,
		"memory_delta_kb": 512.0,
		"processing_time_ms": 33.0
	},
	"large": {
		"average_fps": 35.0,
		"minimum_fps": 25.0,
		"memory_delta_kb": 2048.0,
		"processing_time_ms": 66.0
	}
}

func before_each() -> void:
	await super.before_each()
	
	# Initialize table processor
	_processor = TableProcessorScript.new()
	if not _processor:
		push_error("Failed to create table processor")
		return
	add_child_autofree(_processor)
	track_test_node(_processor)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	# Cleanup test resources
	_test_tables.clear()
	
	if is_instance_valid(_processor):
		_processor.queue_free()
	_processor = null
	
	await super.after_each()

func test_small_table_performance() -> void:
	print_debug("Testing small table processing performance...")
	await _setup_test_table("small")
	
	var metrics := await measure_performance(
		func() -> void:
			TypeSafeMixin._call_node_method_bool(_processor, "process_table", [_test_tables[0]])
			await get_tree().process_frame
	)
	
	verify_performance_metrics(metrics, TABLE_THRESHOLDS.small)

func test_medium_table_performance() -> void:
	print_debug("Testing medium table processing performance...")
	await _setup_test_table("medium")
	
	var metrics := await measure_performance(
		func() -> void:
			TypeSafeMixin._call_node_method_bool(_processor, "process_table", [_test_tables[0]])
			await get_tree().process_frame
	)
	
	verify_performance_metrics(metrics, TABLE_THRESHOLDS.medium)

func test_large_table_performance() -> void:
	print_debug("Testing large table processing performance...")
	await _setup_test_table("large")
	
	var metrics := await measure_performance(
		func() -> void:
			TypeSafeMixin._call_node_method_bool(_processor, "process_table", [_test_tables[0]])
			await get_tree().process_frame
	)
	
	verify_performance_metrics(metrics, TABLE_THRESHOLDS.large)

func test_table_memory_management() -> void:
	print_debug("Testing table memory management...")
	
	var initial_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	
	# Test memory usage with tables of increasing size
	for size in TABLE_SIZES.keys():
		await _setup_test_table(size)
		
		# Process tables multiple times
		for i in range(5):
			TypeSafeMixin._call_node_method_bool(_processor, "process_table", [_test_tables[0]])
			await get_tree().process_frame
		
		# Cleanup tables
		_test_tables.clear()
		await get_tree().process_frame
	
	var final_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var memory_delta := (final_memory - initial_memory) / 1024.0 # KB
	
	assert_lt(memory_delta, PERFORMANCE_THRESHOLDS.memory.leak_threshold_kb,
		"Memory should be properly cleaned up after table processing")

func test_table_stress() -> void:
	print_debug("Running table processing stress test...")
	
	# Setup medium table
	await _setup_test_table("medium")
	
	await stress_test(
		func() -> void:
			TypeSafeMixin._call_node_method_bool(_processor, "process_table", [_test_tables[0]])
			
			# Randomly modify table
			if randf() < 0.2: # 20% chance each frame
				var modification := randi() % 3
				match modification:
					0: # Add row
						_add_test_row(_test_tables[0])
					1: # Remove row
						_remove_random_row(_test_tables[0])
					2: # Modify values
						_modify_random_values(_test_tables[0])
			
			await get_tree().process_frame
	)

func test_mobile_table_performance() -> void:
	if not _is_mobile:
		print_debug("Skipping mobile table test on non-mobile platform")
		return
	
	print_debug("Testing mobile table processing performance...")
	
	# Test under memory pressure
	await simulate_memory_pressure()
	
	# Setup small table (mobile optimized)
	await _setup_test_table("small")
	
	var metrics := await measure_performance(
		func() -> void:
			TypeSafeMixin._call_node_method_bool(_processor, "process_table", [_test_tables[0]])
			await get_tree().process_frame
	)
	
	# Use mobile-specific thresholds
	var mobile_thresholds := {
		"average_fps": PERFORMANCE_THRESHOLDS.fps.mobile_target,
		"minimum_fps": PERFORMANCE_THRESHOLDS.fps.mobile_minimum,
		"memory_delta_kb": PERFORMANCE_THRESHOLDS.memory.mobile_max_delta_mb * 1024,
		"draw_calls_delta": PERFORMANCE_THRESHOLDS.gpu.max_draw_calls / 2
	}
	
	verify_performance_metrics(metrics, mobile_thresholds)

# Helper methods
func _setup_test_table(size_key: String) -> void:
	var config: Dictionary = TABLE_SIZES[size_key] if TABLE_SIZES.has(size_key) else TABLE_SIZES.small
	
	var table := {
		"rows": [],
		"columns": _generate_test_columns(config.columns)
	}
	
	# Generate test rows
	for i in range(config.rows):
		table.rows.append(_generate_test_row(config.columns))
	
	_test_tables.append(table)
	await stabilize_engine(STABILIZE_TIME)

func _generate_test_columns(count: int) -> Array[Dictionary]:
	var columns: Array[Dictionary] = []
	for i in range(count):
		columns.append({
			"name": "Column_%d" % i,
			"type": "string" if i % 2 == 0 else "number"
		})
	return columns

func _generate_test_row(column_count: int) -> Dictionary:
	var row := {}
	for i in range(column_count):
		if i % 2 == 0:
			row["Column_%d" % i] = "Value_%d" % randi()
		else:
			row["Column_%d" % i] = randi() % 100
	return row

func _add_test_row(table: Dictionary) -> void:
	if not table.has("columns") or not table.has("rows"):
		return
	table.rows.append(_generate_test_row(table.columns.size()))

func _remove_random_row(table: Dictionary) -> void:
	if not table.has("rows") or table.rows.is_empty():
		return
	var index: int = randi() % table.rows.size()
	table.rows.remove_at(index)

func _modify_random_values(table: Dictionary) -> void:
	if not table.has("rows") or table.rows.is_empty():
		return
	
	var row_index: int = randi() % table.rows.size()
	var row: Dictionary = table.rows[row_index]
	
	for column in table.columns:
		if randf() < 0.5: # 50% chance to modify each value
			var column_name: String = column.name
			if column.type == "string":
				row[column_name] = "Modified_%d" % randi()
			else:
				row[column_name] = randi() % 100
