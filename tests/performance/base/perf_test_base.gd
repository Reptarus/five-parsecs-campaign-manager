@tool
extends GdUnitGameTest
class_name PerfTestBase

# Performance thresholds
const PERFORMANCE_THRESHOLDS := {
    "fps": {
        "target": 60.0,
        "minimum": 30.0,
        "mobile_target": 30.0,
        "mobile_minimum": 24.0
    },
    "memory": {
        "max_delta_mb": 50.0,
        "leak_threshold_kb": 100.0,
        "mobile_max_delta_mb": 25.0
    },
    "gpu": {
        "max_draw_calls": 100,
        "max_vertices": 10000,
        "max_material_changes": 50
    },
    "physics": {
        "max_bodies": 1000,
        "max_contacts": 2000
    },
    "time": {
        "frame_budget_ms": 16.67,
        "mobile_frame_budget_ms": 33.33
    }
}

# Test configuration
const WARMUP_FRAMES := 3
const COOLDOWN_FRAMES := 2
const STRESS_TEST_DURATION := 5.0
const STABILIZE_TIME := 0.1 # seconds

# Performance metrics
var _metrics := {
    "fps": [],
    "memory": [],
    "draw_calls": [],
    "gpu_memory": [],
    "physics_objects": [],
    "audio_mix_time": [],
    "frame_time": []
}

var _start_time: int
var _end_time: int
var _memory_start: int
var _memory_end: int
var _current_test_name: String = ""
var _is_mobile: bool = false

func before_test() -> void:
    await super.before_test()
    _start_time = Time.get_ticks_msec()
    _memory_start = Performance.get_monitor(Performance.MEMORY_STATIC)
    _is_mobile = OS.has_feature("mobile")
    _reset_metrics()
    
    # Get the name of the current test function
    var stack := get_stack()
    if stack.size() > 0:
        _current_test_name = stack[0]["function"]
    
    # Warm up the engine
    for i in WARMUP_FRAMES:
        await get_tree().process_frame

func after_test() -> void:
    # Cool down period
    for i in COOLDOWN_FRAMES:
        await get_tree().process_frame
        
    _end_time = Time.get_ticks_msec()
    _memory_end = Performance.get_monitor(Performance.MEMORY_STATIC)
    
    var duration := (_end_time - _start_time) / 1000.0
    var memory_used := _memory_end - _memory_start
    
    _print_performance_results(duration, memory_used)
    _check_for_memory_leaks()
    await super.after_test()

func _reset_metrics() -> void:
    for key in _metrics.keys():
        _metrics[key].clear()

func _print_performance_results(duration: float, memory_used: int) -> void:
    var report := "[Performance Report] %s\n" % _current_test_name
    report += "Duration: %.3fs\n" % duration
    report += "Memory Delta: %.2f KB\n" % (memory_used / 1024.0)
    
    # Calculate effective FPS from frame timing data
    var avg_frame_time = _calculate_average(_metrics.frame_time)
    var min_frame_time = _calculate_minimum(_metrics.frame_time)
    var max_frame_time = _calculate_maximum(_metrics.frame_time)
    
    var effective_avg_fps = 1000.0 / max(1.0, avg_frame_time) if avg_frame_time > 0 else 0.0
    var effective_min_fps = 1000.0 / max(1.0, max_frame_time) if max_frame_time > 0 else 0.0
    var effective_max_fps = 1000.0 / max(1.0, min_frame_time) if min_frame_time > 0 else 0.0
    
    report += "Average FPS: %.2f (from %.2f ms frame time)\n" % [effective_avg_fps, avg_frame_time]
    report += "Min FPS: %.2f (from %.2f ms max frame time)\n" % [effective_min_fps, max_frame_time]
    report += "Max FPS: %.2f (from %.2f ms min frame time)\n" % [effective_max_fps, min_frame_time]
    report += "Average Draw Calls: %.2f\n" % _calculate_average(_metrics.draw_calls)
    report += "Peak GPU Memory: %.2f MB\n" % (_calculate_maximum(_metrics.gpu_memory) / (1024.0 * 1024.0))
    report += "Average Physics Objects: %.2f\n" % _calculate_average(_metrics.physics_objects)
    report += "Average Audio Mix Time: %.2f ms\n" % _calculate_average(_metrics.audio_mix_time)
    
    print(report)
    
    # Use frame timing thresholds instead of FPS for better headless compatibility
    var frame_time_threshold := PERFORMANCE_THRESHOLDS.time.frame_budget_ms
    if _is_mobile:
        frame_time_threshold = PERFORMANCE_THRESHOLDS.time.mobile_frame_budget_ms
    
    var memory_threshold := PERFORMANCE_THRESHOLDS.memory.max_delta_mb
    if _is_mobile:
        memory_threshold = PERFORMANCE_THRESHOLDS.memory.mobile_max_delta_mb
    
    # Assert against frame timing instead of FPS (works better in headless mode)
    assert_that(avg_frame_time).override_failure_message(
        "Average frame time (%.2f ms) should be below threshold (%.2f ms)" % [avg_frame_time, frame_time_threshold]
    ).is_less(frame_time_threshold)
    
    assert_that(memory_used / (1024.0 * 1024.0)).override_failure_message(
        "Memory usage (%.2f MB) should be below threshold (%.2f MB)" % [memory_used / (1024.0 * 1024.0), memory_threshold]
    ).is_less(memory_threshold)

func _check_for_memory_leaks() -> void:
    var leak_check_iterations := 5
    var initial_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    
    # Force garbage collection
    for i in leak_check_iterations:
        OS.delay_msec(100)
        await get_tree().process_frame
    
    var final_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    var memory_delta := (final_memory - initial_memory) / 1024.0 # KB
    
    assert_that(memory_delta).override_failure_message(
        "Potential memory leak detected: %.2f KB retained" % memory_delta
    ).is_less(PERFORMANCE_THRESHOLDS.memory.leak_threshold_kb)

# Performance measurement utilities - Headless test compatible
func measure_performance(callable: Callable, iterations: int = 100) -> Dictionary:
    _reset_metrics()
    
    # Use frame timing instead of FPS for headless tests
    var start_time = Time.get_ticks_msec()
    var initial_memory = Performance.get_monitor(Performance.MEMORY_STATIC)
    var initial_draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
    
    # Collect frame timing data (works in headless mode)
    var frame_times: Array[float] = []
    var memory_samples: Array[float] = []
    
    for i in range(iterations):
        var frame_start = Time.get_ticks_msec()
        
        # Execute the callable
        await callable.call()
        await get_tree().process_frame
        
        var frame_end = Time.get_ticks_msec()
        var frame_time = frame_end - frame_start
        frame_times.append(frame_time)
        
        # Collect memory metrics (these work in headless mode)
        var current_memory = Performance.get_monitor(Performance.MEMORY_STATIC)
        memory_samples.append(current_memory)
        
        # Store in metrics arrays
        _metrics.frame_time.append(frame_time)
        _metrics.memory.append(current_memory)
        _metrics.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    
    var end_time = Time.get_ticks_msec()
    var final_memory = Performance.get_monitor(Performance.MEMORY_STATIC)
    var final_draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
    
    # Calculate metrics based on frame timing instead of FPS
    var total_time = (end_time - start_time) / 1000.0 # Convert to seconds
    var avg_frame_time = _calculate_average(frame_times)
    var min_frame_time = _calculate_minimum(frame_times)
    var max_frame_time = _calculate_maximum(frame_times)
    
    # Calculate "effective FPS" from frame timing (for compatibility)
    var effective_fps = 1000.0 / max(1.0, avg_frame_time) if avg_frame_time > 0 else 60.0
    var min_effective_fps = 1000.0 / max(1.0, max_frame_time) if max_frame_time > 0 else 60.0
    var max_effective_fps = 1000.0 / max(1.0, min_frame_time) if min_frame_time > 0 else 60.0
    
    var memory_delta = (final_memory - initial_memory) / 1024.0 # Convert to KB
    var draw_calls_delta = final_draw_calls - initial_draw_calls
    
    return {
        "total_time": total_time,
        "iterations": iterations,
        "average_fps": effective_fps,
        "minimum_fps": min_effective_fps,
        "maximum_fps": max_effective_fps,
        "average_frame_time": avg_frame_time,
        "minimum_frame_time": min_frame_time,
        "maximum_frame_time": max_frame_time,
        "memory_delta_kb": memory_delta,
        "draw_calls_delta": draw_calls_delta,
        "frame_time_stability": _calculate_frame_time_stability(frame_times),
        "performance_score": _calculate_performance_score_from_timing(avg_frame_time, memory_delta)
    }

func verify_performance_metrics(metrics: Dictionary, thresholds: Dictionary) -> void:
    # Use frame timing instead of FPS for headless test compatibility
    var frame_time_target := PERFORMANCE_THRESHOLDS.time.frame_budget_ms
    if _is_mobile:
        frame_time_target = PERFORMANCE_THRESHOLDS.time.mobile_frame_budget_ms
    
    # Verify frame timing (lower is better) - this works in headless mode
    assert_that(metrics.average_frame_time).override_failure_message(
        "Average frame time (%.2f ms) should be below threshold (%.2f ms)" % [metrics.average_frame_time, thresholds.get("average_frame_time", frame_time_target)]
    ).is_less(thresholds.get("average_frame_time", frame_time_target))
    
    assert_that(metrics.maximum_frame_time).override_failure_message(
        "Maximum frame time (%.2f ms) should be below threshold (%.2f ms)" % [metrics.maximum_frame_time, thresholds.get("maximum_frame_time", frame_time_target * 2.0)]
    ).is_less(thresholds.get("maximum_frame_time", frame_time_target * 2.0))
    
    # Memory verification
    assert_that(metrics.memory_delta_kb).override_failure_message(
        "Memory delta (%.2f KB) should be below threshold (%.2f KB)" % [metrics.memory_delta_kb, thresholds.get("memory_delta_kb", PERFORMANCE_THRESHOLDS.memory.max_delta_mb * 1024)]
    ).is_less(thresholds.get("memory_delta_kb", PERFORMANCE_THRESHOLDS.memory.max_delta_mb * 1024))
    
    # Frame time stability verification (higher is better)
    if metrics.has("frame_time_stability"):
        assert_that(metrics.frame_time_stability).override_failure_message(
            "Frame time stability (%.2f) should be above threshold (%.2f)" % [metrics.frame_time_stability, thresholds.get("frame_time_stability", 0.5)]
        ).is_greater(thresholds.get("frame_time_stability", 0.5))

# Statistical utilities
func _calculate_average(values: Array) -> float:
    if values.is_empty():
        return 0.0
    var sum := 0.0
    for value in values:
        sum += value
    return sum / values.size()

func _calculate_minimum(values: Array) -> float:
    if values.is_empty():
        return 0.0
    var min_value: float = values[0]
    for value in values:
        min_value = min(min_value, value)
    return min_value

func _calculate_maximum(values: Array) -> float:
    if values.is_empty():
        return 0.0
    var max_value: float = values[0]
    for value in values:
        max_value = max(max_value, value)
    return max_value

func _calculate_percentile(values: Array, percentile: float) -> float:
    if values.is_empty():
        return 0.0
    var sorted_values := values.duplicate()
    sorted_values.sort()
    var index := int(ceil(sorted_values.size() * percentile) - 1)
    return sorted_values[index]

# Stress testing utilities
func stress_test(callable: Callable) -> void:
    var start_time := Time.get_ticks_msec()
    var end_time := start_time + (STRESS_TEST_DURATION * 1000)
    
    while Time.get_ticks_msec() < end_time:
        await callable.call()
        await get_tree().process_frame
    
    _check_for_memory_leaks()

# Mobile-specific utilities
func simulate_memory_pressure() -> void:
    if not _is_mobile:
        return
        
    var temp_arrays: Array[Array] = []
    # Allocate memory until we hit 80% of max
    while Performance.get_monitor(Performance.MEMORY_STATIC) < Performance.get_monitor(Performance.MEMORY_STATIC_MAX):
        temp_arrays.append(PackedByteArray().resize(1024 * 1024)) # 1MB chunks
        await get_tree().process_frame
    
    # Release memory
    temp_arrays.clear()
    await get_tree().process_frame

func _calculate_fps_stability(fps_samples: Array[float]) -> float:
    if fps_samples.is_empty():
        return 0.0
    
    var avg_fps: float = _calculate_average(fps_samples)
    if avg_fps <= 0.0:
        return 0.0
    
    # Calculate coefficient of variation (lower is more stable)
    var variance: float = 0.0
    for fps in fps_samples:
        variance += pow(fps - avg_fps, 2)
    variance /= fps_samples.size()
    
    var std_deviation: float = sqrt(variance)
    var stability: float = 1.0 - (std_deviation / avg_fps) # Higher value = more stable
    return max(0.0, min(1.0, stability))

func _calculate_performance_score(avg_fps: float, avg_frame_time: float, memory_delta: float) -> float:
    # Calculate a composite performance score (0-100, higher is better)
    var fps_score: float = min(100.0, (avg_fps / 60.0) * 100.0) # Normalize against 60 FPS
    var frame_time_score: float = max(0.0, 100.0 - (avg_frame_time / 16.67) * 100.0) # 16.67ms = 60 FPS
    var memory_score: float = max(0.0, 100.0 - (memory_delta / 1024.0) * 10.0) # Penalize memory usage
    
    return (fps_score * 0.5) + (frame_time_score * 0.3) + (memory_score * 0.2)

func _calculate_frame_time_stability(frame_times: Array[float]) -> float:
    if frame_times.is_empty():
        return 0.0
    
    var avg_frame_time = _calculate_average(frame_times)
    if avg_frame_time <= 0.0:
        return 0.0
    
    var variance: float = 0.0
    for frame_time in frame_times:
        variance += pow(frame_time - avg_frame_time, 2)
    variance /= frame_times.size()
    
    var std_deviation: float = sqrt(variance)
    var stability: float = 1.0 - (std_deviation / avg_frame_time)
    return max(0.0, min(1.0, stability))

func _calculate_performance_score_from_timing(avg_frame_time: float, memory_delta: float) -> float:
    # Calculate a composite performance score (0-100, higher is better)
    var frame_time_score: float = max(0.0, 100.0 - (avg_frame_time / 16.67) * 100.0) # 16.67ms = 60 FPS
    var memory_score: float = max(0.0, 100.0 - (memory_delta / 1024.0) * 10.0) # Penalize memory usage
    
    return (frame_time_score * 0.5) + (memory_score * 0.5)