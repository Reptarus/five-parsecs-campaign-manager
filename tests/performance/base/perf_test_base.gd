@tool
extends GameTest
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

# Performance metrics
var _metrics := {
    "fps": [],
    "memory": [],
    "draw_calls": [],
    "gpu_memory": [],
    "physics_objects": [],
    "audio_mix_time": []
}

var _start_time: int
var _end_time: int
var _memory_start: int
var _memory_end: int
var _current_test_name: String = ""
var _is_mobile: bool = false

func before_each() -> void:
    await super.before_each()
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

func after_each() -> void:
    # Cool down period
    for i in COOLDOWN_FRAMES:
        await get_tree().process_frame
        
    _end_time = Time.get_ticks_msec()
    _memory_end = Performance.get_monitor(Performance.MEMORY_STATIC)
    
    var duration := (_end_time - _start_time) / 1000.0
    var memory_used := _memory_end - _memory_start
    
    _print_performance_results(duration, memory_used)
    _check_for_memory_leaks()
    await super.after_each()

func _reset_metrics() -> void:
    for key in _metrics.keys():
        _metrics[key].clear()

func _print_performance_results(duration: float, memory_used: int) -> void:
    var report := "[Performance Report] %s\n" % _current_test_name
    report += "Duration: %.3fs\n" % duration
    report += "Memory Delta: %.2f KB\n" % (memory_used / 1024.0)
    report += "Average FPS: %.2f\n" % _calculate_average(_metrics.fps)
    report += "Min FPS: %.2f\n" % _calculate_minimum(_metrics.fps)
    report += "95th Percentile FPS: %.2f\n" % _calculate_percentile(_metrics.fps, 0.95)
    report += "Average Draw Calls: %.2f\n" % _calculate_average(_metrics.draw_calls)
    report += "Peak GPU Memory: %.2f MB\n" % (_calculate_maximum(_metrics.gpu_memory) / (1024.0 * 1024.0))
    report += "Average Physics Objects: %.2f\n" % _calculate_average(_metrics.physics_objects)
    report += "Average Audio Mix Time: %.2f ms\n" % _calculate_average(_metrics.audio_mix_time)
    
    print(report)
    
    # Verify against thresholds
    var fps_threshold := PERFORMANCE_THRESHOLDS.fps.minimum
    if _is_mobile:
        fps_threshold = PERFORMANCE_THRESHOLDS.fps.mobile_minimum
    
    var memory_threshold := PERFORMANCE_THRESHOLDS.memory.max_delta_mb
    if _is_mobile:
        memory_threshold = PERFORMANCE_THRESHOLDS.memory.mobile_max_delta_mb
    
    assert_gt(_calculate_average(_metrics.fps), fps_threshold,
        "Average FPS (%.2f) should be above threshold (%.2f)" % [_calculate_average(_metrics.fps), fps_threshold])
    
    assert_lt(memory_used / (1024.0 * 1024.0), memory_threshold,
        "Memory usage (%.2f MB) should be below threshold (%.2f MB)" % [memory_used / (1024.0 * 1024.0), memory_threshold])

func _check_for_memory_leaks() -> void:
    var leak_check_iterations := 5
    var initial_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    
    # Force garbage collection
    for i in leak_check_iterations:
        OS.delay_msec(100)
        await get_tree().process_frame
    
    var final_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    var memory_delta := (final_memory - initial_memory) / 1024.0 # KB
    
    assert_lt(memory_delta, PERFORMANCE_THRESHOLDS.memory.leak_threshold_kb,
        "Potential memory leak detected: %.2f KB retained" % memory_delta)

# Performance measurement utilities
func measure_performance(callable: Callable, iterations: int = 100) -> Dictionary:
    _reset_metrics()
    
    for i in range(iterations):
        await callable.call()
        
        # Collect metrics
        _metrics.fps.append(Engine.get_frames_per_second())
        _metrics.memory.append(Performance.get_monitor(Performance.MEMORY_STATIC))
        _metrics.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
        _metrics.gpu_memory.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
        _metrics.physics_objects.append(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))
        _metrics.audio_mix_time.append(Performance.get_monitor(Performance.AUDIO_OUTPUT_LATENCY))
        
        await stabilize_engine(STABILIZE_TIME)
    
    return {
        "average_fps": _calculate_average(_metrics.fps),
        "minimum_fps": _calculate_minimum(_metrics.fps),
        "95th_percentile_fps": _calculate_percentile(_metrics.fps, 0.95),
        "memory_delta_kb": (_calculate_maximum(_metrics.memory) - _calculate_minimum(_metrics.memory)) / 1024.0,
        "average_draw_calls": _calculate_average(_metrics.draw_calls),
        "peak_gpu_memory_mb": _calculate_maximum(_metrics.gpu_memory) / (1024.0 * 1024.0),
        "average_physics_objects": _calculate_average(_metrics.physics_objects),
        "average_audio_latency_ms": _calculate_average(_metrics.audio_mix_time)
    }

func verify_performance_metrics(metrics: Dictionary, thresholds: Dictionary) -> void:
    var fps_target := PERFORMANCE_THRESHOLDS.fps.target
    if _is_mobile:
        fps_target = PERFORMANCE_THRESHOLDS.fps.mobile_target
    
    assert_gt(metrics.average_fps, thresholds.get("average_fps", fps_target),
        "Average FPS (%.2f) should be above threshold (%.2f)" % [metrics.average_fps, thresholds.get("average_fps", fps_target)])
    
    assert_gt(metrics.minimum_fps, thresholds.get("minimum_fps", fps_target * 0.5),
        "Minimum FPS (%.2f) should be above threshold (%.2f)" % [metrics.minimum_fps, thresholds.get("minimum_fps", fps_target * 0.5)])
    
    assert_lt(metrics.memory_delta_kb, thresholds.get("memory_delta_kb", PERFORMANCE_THRESHOLDS.memory.max_delta_mb * 1024),
        "Memory delta (%.2f KB) should be below threshold (%.2f KB)" % [metrics.memory_delta_kb, thresholds.get("memory_delta_kb", PERFORMANCE_THRESHOLDS.memory.max_delta_mb * 1024)])
    
    assert_lt(metrics.average_draw_calls, thresholds.get("draw_calls_delta", PERFORMANCE_THRESHOLDS.gpu.max_draw_calls),
        "Draw calls (%.2f) should be below threshold (%d)" % [metrics.average_draw_calls, thresholds.get("draw_calls_delta", PERFORMANCE_THRESHOLDS.gpu.max_draw_calls)])

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