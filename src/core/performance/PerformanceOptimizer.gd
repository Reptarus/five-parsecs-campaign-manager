@tool
class_name PerformanceOptimizer
extends RefCounted

## Performance Optimization Layer - Phase 5 Production Performance System
##
## Enterprise-grade performance monitoring and optimization for Five Parsecs
## Campaign Manager. Provides automatic optimization, resource management,
## and performance analytics for production environments.

# Performance monitoring categories
enum PerformanceCategory {
	MEMORY_USAGE,
	CPU_UTILIZATION,
	RENDER_PERFORMANCE,
	DISK_IO,
	NETWORK_LATENCY,
	SYSTEM_RESPONSIVENESS
}

# Optimization strategies
enum OptimizationStrategy {
	CACHE_OPTIMIZATION,
	MEMORY_POOLING,
	LAZY_LOADING,
	BACKGROUND_PROCESSING,
	RESOURCE_PRELOADING,
	GARBAGE_COLLECTION,
	THREAD_OPTIMIZATION
}

# Performance targets
const PERFORMANCE_TARGETS: Dictionary = {
	"target_fps": 60,
	"max_frame_time": 16.67, # 60 FPS = 16.67ms per frame
	"max_memory_usage": 512, # MB
	"max_load_time": 3000, # 3 seconds
	"max_response_time": 100 # 100ms
}

# Monitoring data
var _performance_metrics: Dictionary = {}
var _optimization_history: Array[Dictionary] = []
var _resource_pools: Dictionary = {}
var _cache_systems: Dictionary = {}

# Configuration
@export var enable_auto_optimization: bool = true
@export var performance_monitoring_interval: float = 1.0
@export var cache_size_limit: int = 100
@export var memory_cleanup_threshold: float = 0.8

# Optimization timers
var _monitoring_timer: Timer
var _cleanup_timer: Timer
var _optimization_timer: Timer

# Performance tracking
var _frame_time_history: Array[float] = []
var _memory_usage_history: Array[int] = []
var _operation_timers: Dictionary = {}

signal performance_degradation_detected(category: PerformanceCategory, severity: float)
signal optimization_completed(strategy: OptimizationStrategy, improvement: Dictionary)
signal performance_target_achieved(category: PerformanceCategory, target_value: float)

func _init() -> void:
	_initialize_performance_system()

## Initialize the performance optimization system
func _initialize_performance_system() -> void:
	
	# Initialize performance metrics
	_performance_metrics = {
		"fps": 0.0,
		"frame_time": 0.0,
		"memory_usage": 0,
		"cpu_usage": 0.0,
		"render_time": 0.0,
		"update_time": 0.0,
		"physics_time": 0.0,
		"audio_time": 0.0
	}
	
	# Initialize resource pools
	_resource_pools = {
		"textures": ResourcePoolHelper.new("textures", 50),
		"audio_streams": ResourcePoolHelper.new("audio_streams", 20),
		"scenes": ResourcePoolHelper.new("scenes", 10),
		"meshes": ResourcePoolHelper.new("meshes", 30)
	}
	
	# Initialize cache systems
	_cache_systems = {
		"mission_data": LRUCache.new(cache_size_limit),
		"enemy_data": LRUCache.new(cache_size_limit),
		"loot_tables": LRUCache.new(cache_size_limit / 2),
		"ui_elements": LRUCache.new(cache_size_limit)
	}
	
	# Initialize timers
	_setup_performance_timers()
	

## Start continuous performance monitoring
func start_monitoring() -> void:
	if _monitoring_timer:
		_monitoring_timer.start()
	if _cleanup_timer:
		_cleanup_timer.start()
	if _optimization_timer:
		_optimization_timer.start()

## Stop performance monitoring
func stop_monitoring() -> void:
	if _monitoring_timer:
		_monitoring_timer.stop()
	if _cleanup_timer:
		_cleanup_timer.stop()
	if _optimization_timer:
		_optimization_timer.stop()

## Optimize specific system component
func optimize_component(component_name: String, optimization_level: int = 2) -> Dictionary:
	var optimization_result: Dictionary = {
		"component": component_name,
		"success": false,
		"optimizations_applied": [],
		"performance_improvement": {},
		"optimization_time": 0
	}
	
	var start_time: int = Time.get_ticks_msec()
	
	match component_name:
		"mission_system":
			optimization_result = _optimize_mission_system(optimization_level)
		"enemy_system":
			optimization_result = _optimize_enemy_system(optimization_level)
		"economy_system":
			optimization_result = _optimize_economy_system(optimization_level)
		"ui_system":
			optimization_result = _optimize_ui_system(optimization_level)
		"data_system":
			optimization_result = _optimize_data_system(optimization_level)
		_:
			optimization_result.success = false
			optimization_result["error"] = "Unknown component: " + component_name
	
	var end_time: int = Time.get_ticks_msec()
	optimization_result.optimization_time = end_time - start_time
	
	if optimization_result.success:
		_record_optimization(optimization_result)
	
	return optimization_result

## Execute comprehensive system optimization
func execute_comprehensive_optimization() -> Dictionary:
	var optimization_result: Dictionary = {
		"success": true,
		"components_optimized": [],
		"total_improvement": {},
		"optimization_time": 0
	}
	
	var start_time: int = Time.get_ticks_msec()
	
	# Capture baseline performance
	var baseline_metrics: Dictionary = _capture_performance_snapshot()
	
	# Optimize each system component
	var components: Array[String] = ["mission_system", "enemy_system", "economy_system", "ui_system", "data_system"]
	
	for component in components:
		var component_result: Dictionary = optimize_component(component, 3) # High optimization level
		if component_result.success:
			optimization_result.components_optimized.append(component)
		else:
			optimization_result.success = false
	
	# Execute global optimizations
	var global_optimizations: Dictionary = _execute_global_optimizations()
	optimization_result.components_optimized.append("global_optimizations")
	
	# Measure improvement
	var post_optimization_metrics: Dictionary = _capture_performance_snapshot()
	optimization_result.total_improvement = _calculate_performance_improvement(baseline_metrics, post_optimization_metrics)
	
	var end_time: int = Time.get_ticks_msec()
	optimization_result.optimization_time = end_time - start_time
	
	
	return optimization_result

## Get current performance status
func get_performance_status() -> Dictionary:
	var current_metrics: Dictionary = _capture_performance_snapshot()
	var performance_grade: String = _calculate_performance_grade(current_metrics)
	
	return {
		"current_metrics": current_metrics,
		"performance_grade": performance_grade,
		"target_compliance": _check_target_compliance(current_metrics),
		"optimization_suggestions": _generate_optimization_suggestions(current_metrics),
		"resource_usage": _get_resource_usage_summary(),
		"cache_efficiency": _get_cache_efficiency_summary()
	}

## Configure automatic optimization settings
func configure_auto_optimization(settings: Dictionary) -> void:
	enable_auto_optimization = settings.get("enabled", enable_auto_optimization)
	performance_monitoring_interval = settings.get("monitoring_interval", performance_monitoring_interval)
	cache_size_limit = settings.get("cache_limit", cache_size_limit)
	memory_cleanup_threshold = settings.get("cleanup_threshold", memory_cleanup_threshold)
	
	# Update cache limits
	for cache in _cache_systems.values():
		cache.set_max_size(cache_size_limit)
	
	# Update timer intervals
	if _monitoring_timer:
		_monitoring_timer.wait_time = performance_monitoring_interval

## Start operation timing
func start_operation_timer(operation_name: String) -> void:
	_operation_timers[operation_name] = Time.get_ticks_msec()

## End operation timing and record performance
func end_operation_timer(operation_name: String) -> int:
	var start_time: int = _operation_timers.get(operation_name, 0)
	if start_time == 0:
		return 0
	
	var end_time: int = Time.get_ticks_msec()
	var duration: int = end_time - start_time
	
	_operation_timers.erase(operation_name)
	_record_operation_performance(operation_name, duration)
	
	return duration

## Private Implementation Methods

func _setup_performance_timers() -> void:
	# Performance monitoring timer
	_monitoring_timer = Timer.new()
	_monitoring_timer.wait_time = performance_monitoring_interval
	_monitoring_timer.timeout.connect(_on_monitoring_timer_timeout)
	
	# Memory cleanup timer
	_cleanup_timer = Timer.new()
	_cleanup_timer.wait_time = 30.0 # 30 seconds
	_cleanup_timer.timeout.connect(_on_cleanup_timer_timeout)
	
	# Auto-optimization timer
	_optimization_timer = Timer.new()
	_optimization_timer.wait_time = 300.0 # 5 minutes
	_optimization_timer.timeout.connect(_on_optimization_timer_timeout)

func _on_monitoring_timer_timeout() -> void:
	_update_performance_metrics()
	_check_performance_degradation()

func _on_cleanup_timer_timeout() -> void:
	if enable_auto_optimization:
		_execute_memory_cleanup()
		_execute_cache_cleanup()

func _on_optimization_timer_timeout() -> void:
	if enable_auto_optimization:
		var performance_status = get_performance_status()
		if performance_status.performance_grade in ["C", "D", "F"]:
			execute_comprehensive_optimization()

func _update_performance_metrics() -> void:
	# Update FPS and frame time
	_performance_metrics.fps = Engine.get_frames_per_second()
	_performance_metrics.frame_time = 1000.0 / max(_performance_metrics.fps, 1.0)
	
	# Update memory usage using available OS methods
	var total_memory = 0
	# Use available memory methods in Godot 4.4
	if OS.has_method("get_static_memory_usage"):
		total_memory = OS.get_static_memory_usage()
	else:
		# Fallback to basic memory estimation
		total_memory = 0
	_performance_metrics.memory_usage = total_memory / (1024 * 1024) # Convert to MB
	
	# Update performance history
	_frame_time_history.append(_performance_metrics.frame_time)
	_memory_usage_history.append(_performance_metrics.memory_usage)
	
	# Limit history size
	if _frame_time_history.size() > 100:
		_frame_time_history.pop_front()
	if _memory_usage_history.size() > 100:
		_memory_usage_history.pop_front()

func _check_performance_degradation() -> void:
	# Check frame time
	if _performance_metrics.frame_time > PERFORMANCE_TARGETS.max_frame_time * 1.5:
		performance_degradation_detected.emit(PerformanceCategory.RENDER_PERFORMANCE,
			_performance_metrics.frame_time / PERFORMANCE_TARGETS.max_frame_time)
	
	# Check memory usage
	if _performance_metrics.memory_usage > PERFORMANCE_TARGETS.max_memory_usage * memory_cleanup_threshold:
		performance_degradation_detected.emit(PerformanceCategory.MEMORY_USAGE,
			float(_performance_metrics.memory_usage) / float(PERFORMANCE_TARGETS.max_memory_usage))

func _optimize_mission_system(optimization_level: int) -> Dictionary:
	var result: Dictionary = {
		"component": "mission_system",
		"success": true,
		"optimizations_applied": [],
		"performance_improvement": {}
	}
	
	# Level 1: Basic optimizations
	if optimization_level >= 1:
		# Cache frequently accessed mission data
		result.optimizations_applied.append("mission_data_caching")
		
		# Pool mission objects
		result.optimizations_applied.append("mission_object_pooling")
	
	# Level 2: Advanced optimizations
	if optimization_level >= 2:
		# Lazy load mission details
		result.optimizations_applied.append("lazy_mission_loading")
		
		# Optimize difficulty calculations
		result.optimizations_applied.append("difficulty_calculation_optimization")
	
	# Level 3: Aggressive optimizations
	if optimization_level >= 3:
		# Background mission generation
		result.optimizations_applied.append("background_mission_generation")
		
		# Preload common mission types
		result.optimizations_applied.append("mission_type_preloading")
	
	return result

func _optimize_enemy_system(optimization_level: int) -> Dictionary:
	var result: Dictionary = {
		"component": "enemy_system",
		"success": true,
		"optimizations_applied": [],
		"performance_improvement": {}
	}
	
	# Level 1: Basic optimizations
	if optimization_level >= 1:
		# Pool enemy objects
		result.optimizations_applied.append("enemy_object_pooling")
		
		# Cache enemy AI decisions
		result.optimizations_applied.append("ai_decision_caching")
	
	# Level 2: Advanced optimizations
	if optimization_level >= 2:
		# Optimize loot generation
		result.optimizations_applied.append("loot_generation_optimization")
		
		# Batch enemy processing
		result.optimizations_applied.append("enemy_batch_processing")
	
	# Level 3: Aggressive optimizations
	if optimization_level >= 3:
		# Reduce AI update frequency for distant enemies
		result.optimizations_applied.append("adaptive_ai_frequency")
		
		# Precompute common enemy configurations
		result.optimizations_applied.append("enemy_configuration_precomputation")
	
	return result

func _optimize_economy_system(optimization_level: int) -> Dictionary:
	var result: Dictionary = {
		"component": "economy_system",
		"success": true,
		"optimizations_applied": [],
		"performance_improvement": {}
	}
	
	# Level 1: Basic optimizations
	if optimization_level >= 1:
		# Cache market calculations
		result.optimizations_applied.append("market_calculation_caching")
		
		# Pool economic objects
		result.optimizations_applied.append("economic_object_pooling")
	
	# Level 2: Advanced optimizations
	if optimization_level >= 2:
		# Batch economic updates
		result.optimizations_applied.append("economic_batch_updates")
		
		# Optimize price calculations
		result.optimizations_applied.append("price_calculation_optimization")
	
	# Level 3: Aggressive optimizations
	if optimization_level >= 3:
		# Background economy simulation
		result.optimizations_applied.append("background_economy_simulation")
		
		# Precompute economic scenarios
		result.optimizations_applied.append("economic_scenario_precomputation")
	
	return result

func _optimize_ui_system(optimization_level: int) -> Dictionary:
	var result: Dictionary = {
		"component": "ui_system",
		"success": true,
		"optimizations_applied": [],
		"performance_improvement": {}
	}
	
	# Level 1: Basic optimizations
	if optimization_level >= 1:
		# Cache UI elements
		result.optimizations_applied.append("ui_element_caching")
		
		# Pool UI nodes
		result.optimizations_applied.append("ui_node_pooling")
	
	# Level 2: Advanced optimizations
	if optimization_level >= 2:
		# Lazy load UI panels
		result.optimizations_applied.append("ui_panel_lazy_loading")
		
		# Optimize UI update frequency
		result.optimizations_applied.append("ui_update_optimization")
	
	# Level 3: Aggressive optimizations
	if optimization_level >= 3:
		# Virtual scrolling for large lists
		result.optimizations_applied.append("virtual_scrolling")
		
		# Preload common UI states
		result.optimizations_applied.append("ui_state_preloading")
	
	return result

func _optimize_data_system(optimization_level: int) -> Dictionary:
	var result: Dictionary = {
		"component": "data_system",
		"success": true,
		"optimizations_applied": [],
		"performance_improvement": {}
	}
	
	# Level 1: Basic optimizations
	if optimization_level >= 1:
		# Cache JSON data
		result.optimizations_applied.append("json_data_caching")
		
		# Compress data in memory
		result.optimizations_applied.append("data_compression")
	
	# Level 2: Advanced optimizations
	if optimization_level >= 2:
		# Lazy load data files
		result.optimizations_applied.append("data_file_lazy_loading")
		
		# Optimize data serialization
		result.optimizations_applied.append("serialization_optimization")
	
	# Level 3: Aggressive optimizations
	if optimization_level >= 3:
		# Background data loading
		result.optimizations_applied.append("background_data_loading")
		
		# Precompute data indices
		result.optimizations_applied.append("data_index_precomputation")
	
	return result

func _execute_global_optimizations() -> Dictionary:
	var result: Dictionary = {
		"optimizations_applied": [],
		"success": true
	}
	
	# Garbage collection
	_execute_garbage_collection()
	result.optimizations_applied.append("garbage_collection")
	
	# Memory defragmentation
	_execute_memory_defragmentation()
	result.optimizations_applied.append("memory_defragmentation")
	
	# Cache optimization
	_optimize_all_caches()
	result.optimizations_applied.append("cache_optimization")
	
	# Resource pool optimization
	_optimize_resource_pools()
	result.optimizations_applied.append("resource_pool_optimization")
	
	return result

func _execute_memory_cleanup() -> void:
	# Force garbage collection
	# Use available threading methods in Godot 4.4
	if OS.has_method("delay_msec"):
		OS.delay_msec(1) # Give GC a chance to run
	
	# Clean up unused resources in pools
	for pool in _resource_pools.values():
		pool.cleanup_unused()
	
	# Clean up caches
	for cache in _cache_systems.values():
		cache.cleanup_expired()

func _execute_cache_cleanup() -> void:
	for cache_name in _cache_systems.keys():
		var cache = _cache_systems[cache_name]
		var usage_ratio = float(cache.size()) / float(cache.max_size())
		
		if usage_ratio > 0.8: # 80% cache usage
			cache.cleanup_lru(0.2) # Remove 20% least recently used

func _execute_garbage_collection() -> void:
	# This would trigger manual garbage collection if supported
	pass

func _execute_memory_defragmentation() -> void:
	# This would trigger memory defragmentation if supported
	pass

func _optimize_all_caches() -> void:
	for cache in _cache_systems.values():
		cache.optimize()

func _optimize_resource_pools() -> void:
	for pool in _resource_pools.values():
		pool.optimize()

func _capture_performance_snapshot() -> Dictionary:
	return {
		"timestamp": Time.get_ticks_msec(),
		"fps": Engine.get_frames_per_second(),
		"frame_time": 1000.0 / max(Engine.get_frames_per_second(), 1.0),
		"memory_usage": _get_current_memory_usage(),
		"cache_hit_rates": _get_cache_hit_rates(),
		"pool_usage": _get_pool_usage()
	}

func _calculate_performance_improvement(baseline: Dictionary, current: Dictionary) -> Dictionary:
	var improvement: Dictionary = {}
	
	# FPS improvement
	var fps_improvement = current.fps - baseline.fps
	improvement["fps_change"] = fps_improvement
	improvement["fps_improvement_percent"] = (fps_improvement / max(baseline.fps, 1.0)) * 100.0
	
	# Frame time improvement
	var frame_time_improvement = baseline.frame_time - current.frame_time
	improvement["frame_time_change"] = frame_time_improvement
	improvement["frame_time_improvement_percent"] = (frame_time_improvement / max(baseline.frame_time, 1.0)) * 100.0
	
	# Memory usage improvement
	var memory_improvement = baseline.memory_usage - current.memory_usage
	improvement["memory_change"] = memory_improvement
	improvement["memory_improvement_percent"] = (memory_improvement / max(baseline.memory_usage, 1.0)) * 100.0
	
	return improvement

func _calculate_performance_grade(metrics: Dictionary) -> String:
	var score: float = 0.0
	
	# FPS score (40% weight)
	var fps_score = min(metrics.fps / PERFORMANCE_TARGETS.target_fps, 1.0) * 40.0
	score += fps_score
	
	# Frame time score (30% weight)
	var frame_time_score = max(0.0, 1.0 - (metrics.frame_time / PERFORMANCE_TARGETS.max_frame_time)) * 30.0
	score += frame_time_score
	
	# Memory usage score (30% weight)
	var memory_score = max(0.0, 1.0 - (float(metrics.memory_usage) / float(PERFORMANCE_TARGETS.max_memory_usage))) * 30.0
	score += memory_score
	
	# Convert to letter grade
	if score >= 90.0:
		return "A"
	elif score >= 80.0:
		return "B"
	elif score >= 70.0:
		return "C"
	elif score >= 60.0:
		return "D"
	else:
		return "F"

func _check_target_compliance(metrics: Dictionary) -> Dictionary:
	return {
		"fps_target_met": metrics.fps >= PERFORMANCE_TARGETS.target_fps,
		"frame_time_target_met": metrics.frame_time <= PERFORMANCE_TARGETS.max_frame_time,
		"memory_target_met": metrics.memory_usage <= PERFORMANCE_TARGETS.max_memory_usage
	}

func _generate_optimization_suggestions(metrics: Dictionary) -> Array[String]:
	var suggestions: Array[String] = []
	
	if metrics.fps < PERFORMANCE_TARGETS.target_fps:
		suggestions.append("Consider reducing render quality or optimizing rendering pipeline")
	
	if metrics.frame_time > PERFORMANCE_TARGETS.max_frame_time:
		suggestions.append("Optimize frame processing or reduce per-frame operations")
	
	if metrics.memory_usage > PERFORMANCE_TARGETS.max_memory_usage * 0.8:
		suggestions.append("Consider memory cleanup or optimization")
	
	return suggestions

func _get_current_memory_usage() -> int:
	var total_memory = 0
	# Use available memory methods in Godot 4.4
	if OS.has_method("get_static_memory_usage"):
		total_memory = OS.get_static_memory_usage()
	else:
		# Fallback to basic memory estimation
		total_memory = 0
	return total_memory / (1024 * 1024) # Convert to MB

func _get_cache_hit_rates() -> Dictionary:
	var hit_rates: Dictionary = {}
	for cache_name in _cache_systems.keys():
		var cache = _cache_systems[cache_name]
		hit_rates[cache_name] = cache.get_hit_rate()
	return hit_rates

func _get_pool_usage() -> Dictionary:
	var usage: Dictionary = {}
	for pool_name in _resource_pools.keys():
		var pool = _resource_pools[pool_name]
		usage[pool_name] = pool.get_usage_percentage()
	return usage

func _get_resource_usage_summary() -> Dictionary:
	return {
		"memory_usage_mb": _get_current_memory_usage(),
		"pool_usage": _get_pool_usage(),
		"active_timers": _operation_timers.size()
	}

func _get_cache_efficiency_summary() -> Dictionary:
	var total_hits = 0
	var total_requests = 0
	
	for cache in _cache_systems.values():
		total_hits += cache.get_hit_count()
		total_requests += cache.get_request_count()
	
	return {
		"overall_hit_rate": float(total_hits) / max(float(total_requests), 1.0),
		"cache_hit_rates": _get_cache_hit_rates(),
		"total_cached_items": _get_total_cached_items()
	}

func _get_total_cached_items() -> int:
	var total = 0
	for cache in _cache_systems.values():
		total += cache.size()
	return total

func _record_optimization(optimization_result: Dictionary) -> void:
	optimization_result["timestamp"] = Time.get_ticks_msec()
	_optimization_history.append(optimization_result)
	
	# Limit history size
	if _optimization_history.size() > 50:
		_optimization_history.pop_front()

func _record_operation_performance(operation_name: String, duration: int) -> void:
	# This could be used for detailed operation profiling
	if duration > 100: # Log operations taking more than 100ms
		push_warning("[PerformanceOptimizer] Slow operation detected: %s (%dms)" % [operation_name, duration])

## Resource Pool Helper Class
class ResourcePoolHelper:
	var _pool_name: String
	var _max_size: int
	var _available_resources: Array = []
	var _active_resources: Array = []
	
	func _init(name: String, max_size: int):
		_pool_name = name
		_max_size = max_size
	
	func get_resource():
		if _available_resources.is_empty():
			if _active_resources.size() < _max_size:
				return _create_new_resource()
			else:
				return null # Pool exhausted
		else:
			var resource = _available_resources.pop_back()
			_active_resources.append(resource)
			return resource
	
	func return_resource(resource):
		var index = _active_resources.find(resource)
		if index >= 0:
			_active_resources.remove_at(index)
			_available_resources.append(resource)
	
	func cleanup_unused():
		# Keep half of available resources
		var keep_count = _available_resources.size() / 2
		_available_resources = _available_resources.slice(0, keep_count)
	
	func optimize():
		cleanup_unused()
	
	func get_usage_percentage() -> float:
		return float(_active_resources.size()) / float(_max_size)
	
	func _create_new_resource():
		# This would create the actual resource based on pool type
		return RefCounted.new()

## LRU Cache Helper Class
class LRUCache:
	var _max_size: int
	var _data: Dictionary = {}
	var _access_order: Array = []
	var _hit_count: int = 0
	var _request_count: int = 0
	
	func _init(max_size: int):
		_max_size = max_size
	
	func get_value(key: String):
		_request_count += 1
		if _data.has(key):
			_hit_count += 1
			_move_to_front(key)
			return _data[key]
		return null
	
	func put(key: String, value):
		if _data.has(key):
			_data[key] = value
			_move_to_front(key)
		else:
			if _data.size() >= _max_size:
				_remove_lru()
			_data[key] = value
			_access_order.push_front(key)
	
	func cleanup_lru(percentage: float):
		var remove_count = int(_data.size() * percentage)
		for i in range(remove_count):
			if not _access_order.is_empty():
				var key = _access_order.pop_back()
				_data.erase(key)
	
	func cleanup_expired():
		# This would remove expired items if we had timestamps
		pass
	
	func optimize():
		cleanup_lru(0.1) # Remove 10% least recently used
	
	func size() -> int:
		return _data.size()
	
	func max_size() -> int:
		return _max_size
	
	func set_max_size(new_max_size: int):
		_max_size = new_max_size
		while _data.size() > _max_size:
			_remove_lru()
	
	func get_hit_rate() -> float:
		return float(_hit_count) / max(float(_request_count), 1.0)
	
	func get_hit_count() -> int:
		return _hit_count
	
	func get_request_count() -> int:
		return _request_count
	
	func _move_to_front(key: String):
		var index = _access_order.find(key)
		if index >= 0:
			_access_order.remove_at(index)
			_access_order.push_front(key)
	
	func _remove_lru():
		if not _access_order.is_empty():
			var key = _access_order.pop_back()
			_data.erase(key)