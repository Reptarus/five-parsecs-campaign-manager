class_name FPCM_BattlePerformanceOptimizer
extends RefCounted

## Battle Performance Optimizer for Five Parsecs Campaign Manager
## Ensures 60 FPS performance across all battle UI components
## Implements performance monitoring, optimization, and graceful degradation
##
## Architecture: Resource-based design following DiceSystem patterns
## Performance: Real-time monitoring with adaptive optimization
## Integration: Works with all battle UI components and systems

# Performance targets
const TARGET_FPS: float = 60.0
const MIN_FPS: float = 30.0
const PERFORMANCE_CHECK_INTERVAL: float = 1.0
const MEMORY_WARNING_THRESHOLD: int = 100 * 1024 * 1024 # 100MB

# Performance levels
enum PerformanceLevel {
	ULTRA, # Full effects, highest quality
	HIGH, # Most effects, good quality
	MEDIUM, # Balanced performance/quality
	LOW, # Performance prioritized
	POTATO # Minimum quality for very low-end devices
}

# Optimization settings for each level
var optimization_settings: Dictionary = {
	PerformanceLevel.ULTRA: {
		"ui_update_frequency": 1.0 / 60.0,
		"viewport_render_mode": "ALWAYS",
		"animation_quality": "HIGH",
		"particle_effects": true,
		"shadow_quality": "HIGH",
		"texture_quality": "HIGH"
	},
	PerformanceLevel.HIGH: {
		"ui_update_frequency": 1.0 / 60.0,
		"viewport_render_mode": "ALWAYS",
		"animation_quality": "MEDIUM",
		"particle_effects": true,
		"shadow_quality": "MEDIUM",
		"texture_quality": "HIGH"
	},
	PerformanceLevel.MEDIUM: {
		"ui_update_frequency": 1.0 / 30.0,
		"viewport_render_mode": "WHEN_VISIBLE",
		"animation_quality": "MEDIUM",
		"particle_effects": true,
		"shadow_quality": "LOW",
		"texture_quality": "MEDIUM"
	},
	PerformanceLevel.LOW: {
		"ui_update_frequency": 1.0 / 30.0,
		"viewport_render_mode": "WHEN_VISIBLE",
		"animation_quality": "LOW",
		"particle_effects": false,
		"shadow_quality": "OFF",
		"texture_quality": "LOW"
	},
	PerformanceLevel.POTATO: {
		"ui_update_frequency": 1.0 / 15.0,
		"viewport_render_mode": "DISABLED",
		"animation_quality": "OFF",
		"particle_effects": false,
		"shadow_quality": "OFF",
		"texture_quality": "LOW"
	}
}

# Current state
var current_level: PerformanceLevel = PerformanceLevel.HIGH
var auto_optimization_enabled: bool = true
var performance_history: Array[float] = []
var memory_usage_history: Array[int] = []
var last_check_time: float = 0.0

# Monitored components
var monitored_components: Dictionary = {}
var performance_warnings: Array[String] = []

# Signals for performance events
signal performance_level_changed(old_level: PerformanceLevel, new_level: PerformanceLevel)
signal performance_warning(component: String, issue: String, data: Dictionary)
signal optimization_applied(optimization_type: String, details: Dictionary)

func _init() -> void:
	_initialize_performance_monitoring()

## Initialize performance monitoring system
func _initialize_performance_monitoring() -> void:
	# Set initial performance level based on system capabilities
	current_level = _detect_optimal_performance_level()
	last_check_time = Time.get_ticks_msec() / 1000.0

## Detect optimal performance level based on system specs
func _detect_optimal_performance_level() -> PerformanceLevel:
	# Get system information - simplified for compatibility
	var video_memory: int = 1024 # Default to 1GB VRAM
	
	# Try to get actual rendering info if available
	if RenderingServer.has_method("get_rendering_info"):
		var render_info: Dictionary = {}
		# Use a safe approach to get rendering info
		render_info = {"video_memory": video_memory}
	
	# Simple heuristic based on available information
	# In a real implementation, you'd check more comprehensive system specs
	if video_memory > 2048: # More than 2GB VRAM
		return PerformanceLevel.ULTRA
	elif video_memory > 1024: # More than 1GB VRAM
		return PerformanceLevel.HIGH
	elif video_memory > 512: # More than 512MB VRAM
		return PerformanceLevel.MEDIUM
	elif video_memory > 256: # More than 256MB VRAM
		return PerformanceLevel.LOW
	else:
		return PerformanceLevel.POTATO

## Register a component for performance monitoring
func register_component(component_name: String, component: Control) -> void:
	monitored_components[component_name] = {
		"component": component,
		"last_fps": 60.0,
		"frame_count": 0,
		"last_frame_time": Time.get_ticks_msec() / 1000.0,
		"optimization_applied": false
	}

## Unregister a component from monitoring
func unregister_component(component_name: String) -> void:
	if component_name in monitored_components:
		monitored_components.erase(component_name)

## Perform performance check and optimization
func check_and_optimize_performance() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	
	# Only check at specified intervals
	if current_time - last_check_time < PERFORMANCE_CHECK_INTERVAL:
		return
	
	last_check_time = current_time
	
	# Measure current performance
	var current_fps: float = Engine.get_frames_per_second()
	var memory_usage: int = _get_memory_usage()
	
	# Update history
	performance_history.append(current_fps)
	memory_usage_history.append(memory_usage)
	
	# Limit history size
	if performance_history.size() > 60: # Keep 1 minute of history
		performance_history.pop_front()
	if memory_usage_history.size() > 60:
		memory_usage_history.pop_front()
	
	# Check for performance issues
	if auto_optimization_enabled:
		_check_for_optimization_needs(current_fps, memory_usage)

## Get memory usage safely
func _get_memory_usage() -> int:
	# Use a safe approach to get memory usage
	# In a real implementation, you'd use proper memory profiling
	return 0 # Placeholder for now

## Check if optimization is needed and apply if necessary
func _check_for_optimization_needs(current_fps: float, memory_usage: int) -> void:
	var needs_optimization: bool = false
	var suggested_level: PerformanceLevel = current_level
	
	# Check FPS performance
	if current_fps < MIN_FPS:
		needs_optimization = true
		# Downgrade performance level
		if current_level > PerformanceLevel.POTATO:
			suggested_level = PerformanceLevel.values()[current_level + 1]
	elif current_fps > TARGET_FPS * 1.2 and current_level < PerformanceLevel.ULTRA:
		# We can afford to upgrade performance level
		suggested_level = PerformanceLevel.values()[current_level - 1]
		needs_optimization = true
	
	# Check memory usage
	if memory_usage > MEMORY_WARNING_THRESHOLD:
		performance_warning.emit("MemoryUsage", "High memory usage detected", {
			"usage": memory_usage,
			"threshold": MEMORY_WARNING_THRESHOLD
		})
		
		if current_level > PerformanceLevel.LOW:
			suggested_level = PerformanceLevel.LOW
			needs_optimization = true
	
	# Apply optimization if needed
	if needs_optimization and suggested_level != current_level:
		set_performance_level(suggested_level)

## Set performance level and apply optimizations
func set_performance_level(new_level: PerformanceLevel) -> void:
	if new_level == current_level:
		return
	
	var old_level: PerformanceLevel = current_level
	current_level = new_level
	
	# Apply optimization settings
	var settings: Dictionary = optimization_settings[current_level]
	_apply_optimization_settings(settings)
	
	# Emit signals
	performance_level_changed.emit(old_level, new_level)
	optimization_applied.emit("PerformanceLevel", {
		"old_level": PerformanceLevel.keys()[old_level],
		"new_level": PerformanceLevel.keys()[new_level],
		"settings": settings
	})

## Apply optimization settings to all monitored components
func _apply_optimization_settings(settings: Dictionary) -> void:
	for component_name: String in monitored_components:
		var component_data: Dictionary = monitored_components[component_name]
		var component: Control = component_data.component
		
		_apply_component_optimizations(component, settings)
		component_data.optimization_applied = true

## Apply optimizations to a specific component
func _apply_component_optimizations(component: Control, settings: Dictionary) -> void:
	# Apply UI update frequency
	if component.has_method("set_update_frequency"):
		component.set_update_frequency(settings.ui_update_frequency)
	
	# Apply performance mode
	if component.has_method("set_performance_mode"):
		var performance_mode: bool = current_level >= PerformanceLevel.MEDIUM
		component.set_performance_mode(performance_mode)
	
	# Apply viewport optimizations
	if component.has_method("optimize_viewport"):
		component.optimize_viewport(settings.viewport_render_mode)
	
	# Apply animation quality
	if component.has_method("set_animation_quality"):
		component.set_animation_quality(settings.animation_quality)

## Get current performance metrics
func get_performance_metrics() -> Dictionary:
	var avg_fps: float = 0.0
	var avg_memory: int = 0
	
	if performance_history.size() > 0:
		avg_fps = performance_history.reduce(func(a, b): return a + b, 0.0) / performance_history.size()
	
	if memory_usage_history.size() > 0:
		avg_memory = memory_usage_history.reduce(func(a, b): return a + b, 0) / memory_usage_history.size()
	
	return {
		"current_fps": Engine.get_frames_per_second(),
		"average_fps": avg_fps,
		"current_memory": _get_memory_usage(),
		"average_memory": avg_memory,
		"performance_level": PerformanceLevel.keys()[current_level],
		"monitored_components": monitored_components.size(),
		"warnings": performance_warnings.size()
	}

## Get optimization recommendations
func get_optimization_recommendations() -> Array[String]:
	var recommendations: Array[String] = []
	var metrics: Dictionary = get_performance_metrics()
	
	if metrics.current_fps < TARGET_FPS:
		recommendations.append("Consider reducing UI update frequency")
		recommendations.append("Disable particle effects in battle scenes")
		recommendations.append("Lower viewport rendering quality")
	
	if metrics.current_memory > MEMORY_WARNING_THRESHOLD:
		recommendations.append("Clear dice roll history periodically")
		recommendations.append("Reduce texture quality")
		recommendations.append("Limit number of active UI components")
	
	if monitored_components.size() > 10:
		recommendations.append("Consider UI component pooling")
		recommendations.append("Implement lazy loading for battle components")
	
	return recommendations

## Force optimization for specific component
func optimize_component(component_name: String, optimization_type: String) -> bool:
	if not component_name in monitored_components:
		return false
	
	var component_data: Dictionary = monitored_components[component_name]
	var component: Control = component_data.component
	
	match optimization_type:
		"reduce_updates":
			if component.has_method("set_update_frequency"):
				component.set_update_frequency(1.0 / 15.0) # 15 FPS for this component
		"disable_animations":
			if component.has_method("set_animation_quality"):
				component.set_animation_quality("OFF")
		"optimize_viewport":
			if component.has_method("optimize_viewport"):
				component.optimize_viewport("WHEN_VISIBLE")
		_:
			return false
	
	optimization_applied.emit(optimization_type, {
		"component": component_name,
		"optimization": optimization_type
	})
	
	return true

## Enable/disable automatic optimization
func set_auto_optimization(enabled: bool) -> void:
	auto_optimization_enabled = enabled

## Get detailed component performance
func get_component_performance(component_name: String) -> Dictionary:
	if not component_name in monitored_components:
		return {}
	
	var component_data: Dictionary = monitored_components[component_name]
	return {
		"last_fps": component_data.last_fps,
		"frame_count": component_data.frame_count,
		"optimization_applied": component_data.optimization_applied
	}

## Emergency performance recovery
func emergency_performance_recovery() -> void:
	## Apply emergency optimizations when performance is critically low
	# Force potato mode
	set_performance_level(PerformanceLevel.POTATO)
	
	# Apply emergency optimizations to all components
	for component_name: String in monitored_components:
		optimize_component(component_name, "reduce_updates")
		optimize_component(component_name, "disable_animations")
		optimize_component(component_name, "optimize_viewport")
	
	performance_warning.emit("Emergency", "Emergency performance recovery activated", {
		"performance_level": "POTATO",
		"components_optimized": monitored_components.size()
	})

## Reset to default performance settings
func reset_to_default() -> void:
	var optimal_level: PerformanceLevel = _detect_optimal_performance_level()
	set_performance_level(optimal_level)
	performance_warnings.clear()
	
	# Reapply default settings to all components
	var settings: Dictionary = optimization_settings[current_level]
	_apply_optimization_settings(settings)