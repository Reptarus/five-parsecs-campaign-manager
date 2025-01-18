extends "res://tests/test_base.gd"

const PERFORMANCE_THRESHOLD = 1.0 # Default threshold in seconds

var _start_time: int
var _end_time: int
var _memory_start: int
var _memory_end: int
var _current_test_name: String = ""

func before_each():
    super.before_each()
    _start_time = Time.get_ticks_msec()
    _memory_start = Performance.get_monitor(Performance.MEMORY_STATIC)
    # Get the name of the current test function
    var stack = get_stack()
    if stack.size() > 0:
        _current_test_name = stack[0]["function"]

func after_each():
    _end_time = Time.get_ticks_msec()
    _memory_end = Performance.get_monitor(Performance.MEMORY_STATIC)
    
    var duration = (_end_time - _start_time) / 1000.0
    var memory_used = _memory_end - _memory_start
    
    _print_performance_results(duration, memory_used)
    super.after_each()

func _print_performance_results(duration: float, memory_used: int) -> void:
    print("[Performance] {test}: {time}s, Memory: {mem}KB".format({
        "test": _current_test_name,
        "time": duration,
        "mem": memory_used / 1024.0
    }))
    
    # Assert performance is within acceptable threshold
    assert_lt(duration, PERFORMANCE_THRESHOLD,
        "Performance test '{test}' exceeded threshold ({actual}s > {expected}s)".format({
            "test": _current_test_name,
            "actual": duration,
            "expected": PERFORMANCE_THRESHOLD
        })
    )

# Helper method to run code with timing
func time_block(description: String, callable: Callable) -> float:
    var block_start = Time.get_ticks_msec()
    callable.call()
    var block_end = Time.get_ticks_msec()
    var duration = (block_end - block_start) / 1000.0
    
    print("[Block] {desc}: {time}s".format({
        "desc": description,
        "time": duration
    }))
    
    return duration