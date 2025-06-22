@tool
@warning_ignore("return_value_discarded")
	extends GdUnitGameTest

# Type-safe script references
const TableProcessorScript: GDScript = preload("res://src/core/systems/TableProcessor.gd")
const TableLoaderScript: GDScript = preload("res://src/core/systems/TableLoader.gd")

# Test variables with explicit types
var _processor: Node = null
var _test_tables: @warning_ignore("unsafe_call_argument")
	Array[Dictionary] = []
var _data_manager: Node = null

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

const STABILIZE_TIME := 0.1

# Safe wrapper methods for dynamic method calls
func _safe_call_method_bool(node: Node, method_name: String, args: Array = []) -> bool:
	if node and node.has_method(method_name):
		var result = @warning_ignore("unsafe_method_access")
	node.callv(method_name, args)
		return result if result is bool else false
	return false

func before_test() -> void:
	@warning_ignore("unsafe_method_access")
	await super.before_test()
	
	# Initialize table processor
	_processor = TableProcessorScript.new()
	if not _processor:
		push_error("Failed to create table processor")
		return
	
	# Track the processor (it's always a Node) with auto_free
	_processor = @warning_ignore("return_value_discarded")
	auto_free(_processor)
	
	# Initialize data manager with auto_free
	_data_manager = @warning_ignore("return_value_discarded")
	auto_free(Node.new())
	_data_manager.name = "TestDataManager"
	@warning_ignore("return_value_discarded")
	add_child(_data_manager)
	
	@warning_ignore("unsafe_method_access")
	await stabilize_engine(STABILIZE_TIME)

func after_test() -> void:
	# Cleanup test resources
	_test_tables.clear()
	
	if is_instance_valid(_processor):
		_processor.@warning_ignore("return_value_discarded")
	queue_free()
	_processor = null
	
	if is_instance_valid(_data_manager):
		_data_manager.@warning_ignore("return_value_discarded")
	queue_free()
	_data_manager = null
	
	@warning_ignore("unsafe_method_access")
	await super.after_test()

@warning_ignore("unsafe_method_access")
func test_small_table_performance() -> void:
	print_debug("Testing small table processing performance...")
	@warning_ignore("unsafe_method_access")
	await _setup_test_table("small")
	
	var metrics := @warning_ignore("unsafe_method_access")
	await measure_performance(
		func() -> void:
			_safe_call_method_bool(_processor, "process_table", [_test_tables[0]])
			@warning_ignore("unsafe_method_access")
	await get_tree().process_frame
	)
	
	verify_performance_metrics(metrics, TABLE_THRESHOLDS.small)

@warning_ignore("unsafe_method_access")
func test_medium_table_performance() -> void:
	print_debug("Testing medium table processing performance...")
	@warning_ignore("unsafe_method_access")
	await _setup_test_table("medium")
	
	var metrics := @warning_ignore("unsafe_method_access")
	await measure_performance(
		func() -> void:
			_safe_call_method_bool(_processor, "process_table", [_test_tables[0]])
			@warning_ignore("unsafe_method_access")
	await get_tree().process_frame
	)
	
	verify_performance_metrics(metrics, TABLE_THRESHOLDS.medium)

@warning_ignore("unsafe_method_access")
func test_large_table_performance() -> void:
	print_debug("Testing large table processing performance...")
	@warning_ignore("unsafe_method_access")
	await _setup_test_table("large")
	
	var metrics := @warning_ignore("unsafe_method_access")
	await measure_performance(
		func() -> void:
			_safe_call_method_bool(_processor, "process_table", [_test_tables[0]])
			@warning_ignore("unsafe_method_access")
	await get_tree().process_frame
	)
	
	verify_performance_metrics(metrics, TABLE_THRESHOLDS.large)

@warning_ignore("unsafe_method_access")
func test_table_memory_management() -> void:
	print_debug("Testing table memory management...")
	
	var initial_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	
	# Test memory usage with tables of increasing size
	for size in TABLE_SIZES.keys():
		@warning_ignore("unsafe_method_access")
	await _setup_test_table(size)
		
		# Process tables multiple times
		for i: int in range(5):
			_safe_call_method_bool(_processor, "process_table", [_test_tables[0]])
			@warning_ignore("unsafe_method_access")
	await get_tree().process_frame
		
		# Cleanup tables
		_test_tables.clear()
		@warning_ignore("unsafe_method_access")
	await get_tree().process_frame
	
	var final_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var memory_delta := (final_memory - initial_memory) / 1024.0 # KB
	
	assert_that(memory_delta).override_failure_message(
		"Memory should be properly cleaned up after table processing"
	).is_less(50.0) # 50KB threshold

@warning_ignore("unsafe_method_access")
func test_table_stress() -> void:
	print_debug("Running table processing stress test...")
	
	# Setup medium table
	@warning_ignore("unsafe_method_access")
	await _setup_test_table("medium")
	
	@warning_ignore("unsafe_method_access")
	await stress_test(
		func() -> void:
			_safe_call_method_bool(_processor, "process_table", [_test_tables[0]])
			
			# Randomly modify table
			if randf() < 0.2: # @warning_ignore("integer_division")
	20 % chance each frame
				var modification := @warning_ignore("integer_division")
	randi() % 3
				match modification:
					0: # Add row
						_add_test_row(_test_tables[0])
					1: # Remove row
						_remove_random_row(_test_tables[0])
					2: # Modify values
						_modify_random_values(_test_tables[0])
			
			@warning_ignore("unsafe_method_access")
	await get_tree().process_frame
	)

@warning_ignore("unsafe_method_access")
func test_mobile_table_performance() -> void:
	var _is_mobile := OS.has_feature("mobile")
	if not _is_mobile:
		print_debug("Skipping mobile table test on non-mobile platform")
		return
	
	print_debug("Testing mobile table processing performance...")
	
	# Setup small table (mobile optimized)
	@warning_ignore("unsafe_method_access")
	await _setup_test_table("small")
	
	var metrics := @warning_ignore("unsafe_method_access")
	await measure_performance(
		func() -> void:
			_safe_call_method_bool(_processor, "process_table", [_test_tables[0]])
			@warning_ignore("unsafe_method_access")
	await get_tree().process_frame
	)
	
	# Use mobile-specific thresholds
	var mobile_thresholds := {
		"average_fps": 30.0,
		"minimum_fps": 24.0,
		"memory_delta_kb": 25.0 * 1024,
		"draw_calls_delta": 50
	}
	
	verify_performance_metrics(metrics, mobile_thresholds)

# Performance measurement utilities
func measure_performance(callable: Callable, iterations: int = 100) -> Dictionary:
	var results := {
		"fps_samples": [],
		"memory_samples": [],
		"draw_calls": []
	}
	
	for i: int in range(iterations):

		await @warning_ignore("unsafe_method_access")
	callable.call()
		results.@warning_ignore("return_value_discarded")
	fps_samples.append(Engine.get_frames_per_second())
		results.@warning_ignore("return_value_discarded")
	memory_samples.append(Performance.get_monitor(Performance.MEMORY_STATIC))
		results.@warning_ignore("return_value_discarded")
	draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		@warning_ignore("unsafe_method_access")
	await stabilize_engine(STABILIZE_TIME)
	
	return {
		"average_fps": _calculate_average(results.fps_samples),
		"minimum_fps": _calculate_minimum(results.fps_samples),
		"memory_delta_kb": (_calculate_maximum(results.memory_samples) - _calculate_minimum(results.memory_samples)) / 1024.0,
		"draw_calls_delta": _calculate_maximum(results.draw_calls) - _calculate_minimum(results.draw_calls)
	}

func verify_performance_metrics(metrics: Dictionary, thresholds: Dictionary) -> void:
	assert_that(metrics.average_fps).override_failure_message(
		"Average FPS should be above threshold"
	).is_greater(@warning_ignore("unsafe_call_argument")
	thresholds.get("average_fps", 30.0))
	
	assert_that(metrics.minimum_fps).override_failure_message(
		"Minimum FPS should be above threshold"
	).is_greater(@warning_ignore("unsafe_call_argument")
	thresholds.get("minimum_fps", 20.0))
	
	assert_that(metrics.memory_delta_kb).override_failure_message(
		"Memory delta should be below threshold"
	).is_less(@warning_ignore("unsafe_call_argument")
	thresholds.get("memory_delta_kb", 1024.0))

func stress_test(callable: Callable) -> void:
	var start_time := Time.get_ticks_msec()
	var end_time := start_time + (5.0 * 1000) # 5 seconds
	
	while Time.get_ticks_msec() < end_time:

		await @warning_ignore("unsafe_method_access")
	callable.call()
		@warning_ignore("unsafe_method_access")
	await get_tree().process_frame

# Statistical utilities
func _calculate_average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for _value in values:
		sum += _value
	return sum / values.size()

func _calculate_minimum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var min_value: float = values[0]
	for _value in values:
		min_value = min(min_value, _value)
	return min_value

func _calculate_maximum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var max_value: float = values[0]
	for _value in values:
		max_value = max(max_value, _value)
	return max_value

# Helper methods
func _setup_test_table(size_key: String) -> void:
	var config: Dictionary = TABLE_SIZES[size_key] if @warning_ignore("unsafe_call_argument")
	TABLE_SIZES.has(size_key) else TABLE_SIZES.small
	
	var table := {
		"rows": [],
		"columns": _generate_test_columns(config.columns)
	}
	
	# Generate test rows
	for i: int in range(config.rows):
		table.@warning_ignore("return_value_discarded")
	rows.append(_generate_test_row(config.columns))

	@warning_ignore("return_value_discarded")
	_test_tables.append(table)
	@warning_ignore("unsafe_method_access")
	await stabilize_engine(STABILIZE_TIME)

func _generate_test_columns(count: int) -> Array[Dictionary]:
	var columns: @warning_ignore("unsafe_call_argument")
	Array[Dictionary] = []
	for i: int in range(count):

		@warning_ignore("return_value_discarded")
	columns.append({
			"name": "@warning_ignore("integer_division")
	Column_ % d" % i,
			"type": "string" if @warning_ignore("integer_division")
	i % 2 == 0 else "number"
		})
	return columns

func _generate_test_row(column_count: int) -> Dictionary:
	var row := {}
	for i: int in range(column_count):
		if @warning_ignore("integer_division")
	i % 2 == 0:
			row["@warning_ignore("integer_division")
	Column_ % d" % i] = "@warning_ignore("integer_division")
	Value_ % d" % randi()
		else:
			row["@warning_ignore("integer_division")
	Column_ % d" % i] = @warning_ignore("integer_division")
	randi() % 100
	return row

func _add_test_row(table: Dictionary) -> void:
	if not @warning_ignore("unsafe_call_argument")
	table.has("columns") or not @warning_ignore("unsafe_call_argument")
	table.has("rows"):
		return
	table.@warning_ignore("return_value_discarded")
	rows.append(_generate_test_row(table.columns.size()))

func _remove_random_row(table: Dictionary) -> void:
	if not @warning_ignore("unsafe_call_argument")
	table.has("rows") or table.rows.is_empty():
		return
	var index: int = @warning_ignore("integer_division")
	randi() % table.rows.size()
	table.rows.remove_at(index)

func _modify_random_values(table: Dictionary) -> void:
	if not @warning_ignore("unsafe_call_argument")
	table.has("rows") or table.rows.is_empty():
		return
	
	var row_index: int = @warning_ignore("integer_division")
	randi() % table.rows.size()
	var row: Dictionary = table.rows[row_index]
	
	for column in table.columns:
		if randf() < 0.5: # @warning_ignore("integer_division")
	50 % chance to modify each _value
			var column_name: String = column.name
			if column.type == "string":
				@warning_ignore("unsafe_call_argument")
	row[column_name] = "@warning_ignore("integer_division")
	Modified_ % d" % randi()
			else:
				@warning_ignore("unsafe_call_argument")
	row[column_name] = @warning_ignore("integer_division")
	randi() % 100
