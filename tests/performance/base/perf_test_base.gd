@tool
extends GdUnitGameTest

# Performance Test Base Class
# Universal Mock Strategy - Base Performance Testing Framework

# Core performance tracking
var _start_time: int = 0
var _peak_memory: float = 0.0
var _metrics: Dictionary = {
	"fps": [],
	"frame_time": [],
	"memory": [],
	"draw_calls": [],
	"gpu_memory": [],
	"physics_objects": []
}

# Performance thresholds
const DEFAULT_FPS_THRESHOLD: float = 30.0
const DEFAULT_MEMORY_THRESHOLD: float = 100.0 # MB
const DEFAULT_FRAME_TIME_THRESHOLD: float = 33.33 # ms (30 FPS)

func before_test() -> void:
	super.before_test()
	_reset_metrics()
	_start_performance_monitoring()

func after_test() -> void:
	_stop_performance_monitoring()
	super.after_test()

func _reset_metrics() -> void:
	_metrics = {
		"fps": [],
		"frame_time": [],
		"memory": [],
		"draw_calls": [],
		"gpu_memory": [],
		"physics_objects": []
	}
	_start_time = 0
	_peak_memory = 0.0

func _start_performance_monitoring() -> void:
	_start_time = Time.get_ticks_msec()
	_peak_memory = Performance.get_monitor(Performance.MEMORY_STATIC)

func _stop_performance_monitoring() -> void:
	# Final performance snapshot
	_capture_performance_snapshot()

func _capture_performance_snapshot() -> void:
	_metrics.fps.append(Engine.get_frames_per_second())
	_metrics.frame_time.append(Performance.get_monitor(Performance.TIME_PROCESS))
	_metrics.memory.append(Performance.get_monitor(Performance.MEMORY_STATIC))
	_metrics.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_metrics.gpu_memory.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	_metrics.physics_objects.append(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	
	# Update peak memory
	var current_memory: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	_peak_memory = max(_peak_memory, current_memory)

func run_performance_test(test_callable: Callable, iterations: int = 100) -> Dictionary:
	_reset_metrics()
	
	for i: int in range(iterations):
		test_callable.call()
		_capture_performance_snapshot()
		await get_tree().process_frame
	
	return _generate_performance_report()

func _generate_performance_report() -> Dictionary:
	var duration: float = (Time.get_ticks_msec() - _start_time) / 1000.0
	var memory_used: float = _peak_memory - Performance.get_monitor(Performance.MEMORY_STATIC)
	
	var report: String = "\n=== Performance Report ===\n"
	report += "Duration: %.3fs\n" % duration
	report += "Memory Delta: %.2f KB\n" % (memory_used / 1024.0)
	
	# Calculate effective FPS from frame timing data
	var avg_frame_time = _calculate_average(_metrics.frame_time)
	var min_frame_time = _calculate_minimum(_metrics.frame_time)
	var max_frame_time = _calculate_maximum(_metrics.frame_time)
	var effective_avg_fps = 1000.0 / avg_frame_time if avg_frame_time > 0 else 0.0
	var effective_min_fps = 1000.0 / max_frame_time if max_frame_time > 0 else 0.0
	var effective_max_fps = 1000.0 / min_frame_time if min_frame_time > 0 else 0.0
	
	report += "Average FPS: %.2f (from %.2f ms frame time)\n" % [effective_avg_fps, avg_frame_time]
	report += "Min FPS: %.2f (from %.2f ms max frame time)\n" % [effective_min_fps, max_frame_time]
	report += "Max FPS: %.2f (from %.2f ms min frame time)\n" % [effective_max_fps, min_frame_time]
	report += "Average Draw Calls: %.2f\n" % _calculate_average(_metrics.draw_calls)
	report += "Peak GPU Memory: %.2f MB\n" % (_calculate_maximum(_metrics.gpu_memory) / (1024.0 * 1024.0))
	report += "Average Physics Objects: %.2f\n" % _calculate_average(_metrics.physics_objects)
	
	print_debug(report)
	
	return {
		"duration": duration,
		"memory_delta_mb": memory_used / (1024.0 * 1024.0),
		"average_fps": effective_avg_fps,
		"min_fps": effective_min_fps,
		"max_fps": effective_max_fps,
		"average_frame_time": avg_frame_time,
		"average_draw_calls": _calculate_average(_metrics.draw_calls),
		"peak_gpu_memory_mb": _calculate_maximum(_metrics.gpu_memory) / (1024.0 * 1024.0),
		"average_physics_objects": _calculate_average(_metrics.physics_objects)
	}

func assert_performance_thresholds(metrics: Dictionary, fps_threshold: float = DEFAULT_FPS_THRESHOLD, memory_threshold: float = DEFAULT_MEMORY_THRESHOLD, frame_time_threshold: float = DEFAULT_FRAME_TIME_THRESHOLD) -> void:
	var memory_used: float = metrics.get("memory_delta_mb", 0.0)
	var avg_frame_time: float = metrics.get("average_frame_time", 0.0)
	
	assert_that(avg_frame_time).is_less(frame_time_threshold)
	assert_that(memory_used).is_less(memory_threshold)

func _check_for_memory_leaks() -> void:
	var current_memory: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var memory_delta: float = current_memory - _peak_memory
	
	if memory_delta > (10.0 * 1024.0 * 1024.0): # 10MB threshold
		print_debug("WARNING: Potential memory leak detected. Memory delta: %.2f MB" % (memory_delta / (1024.0 * 1024.0)))

func stabilize_engine(wait_time: float = 0.1) -> void:
	for i: int in range(3):
		await get_tree().process_frame
	await get_tree().create_timer(wait_time).timeout

# Helper calculation functions
func _calculate_average(values: Array) -> float:
	if values.is_empty(): return 0.0
	var sum: float = 0.0
	for value in values: sum += value
	return sum / values.size()

func _calculate_minimum(values: Array) -> float:
	if values.is_empty(): return 0.0
	var min_val: float = values[0]
	for value in values: min_val = min(min_val, value)
	return min_val

func _calculate_maximum(values: Array) -> float:
	if values.is_empty(): return 0.0
	var max_val: float = values[0]
	for value in values: max_val = max(max_val, value)
	return max_val
