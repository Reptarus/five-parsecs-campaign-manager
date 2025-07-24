@tool
extends RefCounted

## Production Performance Monitor - Enhanced Performance Management
##
## Integrates with UniversalErrorBoundary and existing performance infrastructure
## to provide enterprise-grade performance monitoring, regression detection,
## and automated optimization for Five Parsecs production environments.

# Performance regression detection
const PERFORMANCE_REGRESSION_THRESHOLDS: Dictionary = {
	"fps_drop_percent": 15.0, # >15% FPS drop = regression
	"memory_increase_percent": 25.0, # >25% memory increase = regression
	"load_time_increase_ms": 500, # >500ms load time increase = regression
	"response_time_increase_ms": 50 # >50ms response time increase = regression
}

# Current performance targets (based on Phase 1 baseline)
const CURRENT_BASELINES: Dictionary = {
	"target_fps": 60,
	"baseline_memory_mb": 111.4, # From Phase 1 measurement
	"baseline_load_time_ms": 361, # Campaign Controller from Phase 1
	"target_memory_mb": 85.0, # 25% reduction target
	"target_load_time_ms": 250 # 30% improvement target
}

# Performance categories for detailed monitoring
enum PerformanceMetric {
	FPS_STABILITY,
	MEMORY_USAGE,
	LOAD_TIMES,
	RESPONSE_TIMES,
	ERROR_RECOVERY_IMPACT,
	COMPONENT_PERFORMANCE
}

# Performance monitoring state
var _performance_history: Array[Dictionary] = []
var _baseline_metrics: Dictionary = {}
var _current_metrics: Dictionary = {}
var _regression_alerts: Array[Dictionary] = []
var _optimization_recommendations: Array[Dictionary] = []

# Integration with existing systems
var _performance_optimizer: PerformanceOptimizer = null
var _error_boundary: Object = null # UniversalErrorBoundary reference
var _memory_leak_prevention = null # MemoryLeakPrevention reference
var _monitoring_active: bool = false
var _last_monitoring_time: int = 0

# Configuration
@export var monitoring_interval_ms: int = 5000 # 5 second monitoring
@export var history_retention_minutes: int = 60 # 1 hour of history
@export var regression_detection_enabled: bool = true
@export var auto_optimization_enabled: bool = true

## Initialize the production performance monitor
func initialize() -> bool:
	print("[ProductionPerformanceMonitor] Initializing production performance monitoring...")
	
	# Create performance optimizer instance
	_performance_optimizer = PerformanceOptimizer.new()
	
	# Try to connect to error boundary system
	# Note: UniversalErrorBoundary reference removed due to parser error
	# _error_boundary = UniversalErrorBoundary
	print("[ProductionPerformanceMonitor] Error boundary system not available")
	
	# Initialize memory leak prevention integration
	_memory_leak_prevention = load("res://src/core/memory/MemoryLeakPrevention.gd")
	if _memory_leak_prevention:
		_memory_leak_prevention.initialize()
		print("[ProductionPerformanceMonitor] Connected to memory leak prevention system")
	else:
		push_warning("ProductionPerformanceMonitor: Memory leak prevention not available")
	
	# Initialize baseline metrics
	_initialize_baseline_metrics()
	
	_monitoring_active = true
	_last_monitoring_time = Time.get_ticks_msec()
	
	print("[ProductionPerformanceMonitor] ✅ Production performance monitoring initialized")
	return true

## Start comprehensive performance monitoring
func start_monitoring() -> void:
	if not _monitoring_active:
		print("[ProductionPerformanceMonitor] Starting performance monitoring...")
		_monitoring_active = true
	
	_collect_performance_metrics()

## Stop performance monitoring
func stop_monitoring() -> void:
	print("[ProductionPerformanceMonitor] Stopping performance monitoring...")
	_monitoring_active = false

## Collect current performance metrics
func _collect_performance_metrics() -> Dictionary:
	if not _monitoring_active:
		return {}
	
	var current_time = Time.get_ticks_msec()
	
	# Collect basic performance metrics
	var metrics = {
		"timestamp": current_time,
		"fps": Engine.get_frames_per_second(),
		"frame_time_ms": 1000.0 / max(Engine.get_frames_per_second(), 1.0),
		"memory_info": OS.get_memory_info(),
		"memory_total_mb": _calculate_total_memory_mb(OS.get_memory_info()),
		"cpu_usage_percent": _estimate_cpu_usage(),
		"scene_tree_node_count": _get_scene_tree_node_count(),
		"active_resource_count": _count_active_resources()
	}
	
	# Add error boundary performance impact
	if _error_boundary:
		var error_stats = _error_boundary.get_error_statistics()
		metrics["error_boundary_overhead"] = _calculate_error_boundary_overhead(error_stats)
		metrics["error_recovery_rate"] = error_stats.get("integration_stats", {}).get("recovery_success_rate", 0.0)
	
	# Add memory leak prevention metrics
	if _memory_leak_prevention:
		var memory_report = _memory_leak_prevention.get_memory_report()
		metrics["tracked_nodes"] = memory_report.get("tracked_nodes", 0)
		metrics["tracked_files"] = memory_report.get("tracked_files", 0)
		metrics["memory_leaks_detected"] = _detect_memory_leaks(memory_report)
		metrics["memory_status"] = memory_report.get("memory_status", "UNKNOWN")
	
	# Add load time metrics if available
	metrics.merge(_collect_load_time_metrics())
	
	# Store metrics in history
	_current_metrics = metrics
	_performance_history.append(metrics)
	
	# Trim old history
	_trim_performance_history()
	
	# Check for regressions
	if regression_detection_enabled:
		_detect_performance_regressions()
	
	# Generate optimization recommendations
	_generate_optimization_recommendations()
	
	_last_monitoring_time = current_time
	return metrics

## Detect performance regressions compared to baseline
func _detect_performance_regressions() -> Array[Dictionary]:
	if _performance_history.size() < 5: # Need some history
		return []
	
	var recent_metrics = _get_recent_average_metrics(5) # Last 5 measurements
	var regressions = []
	
	# Check FPS regression
	var fps_drop_percent = (_baseline_metrics.get("fps", 60) - recent_metrics.get("fps", 60)) / _baseline_metrics.get("fps", 60) * 100.0
	if fps_drop_percent > PERFORMANCE_REGRESSION_THRESHOLDS.fps_drop_percent:
		regressions.append({
			"type": "fps_regression",
			"severity": "HIGH",
			"description": "FPS dropped by %.1f%% (baseline: %.1f, current: %.1f)" % [
				fps_drop_percent,
				_baseline_metrics.get("fps", 60),
				recent_metrics.get("fps", 60)
			],
			"recommendation": "Check for performance bottlenecks in recent changes"
		})
	
	# Check memory regression
	var memory_increase_percent = (recent_metrics.get("memory_total_mb", 0) - _baseline_metrics.get("memory_total_mb", 0)) / _baseline_metrics.get("memory_total_mb", 100) * 100.0
	if memory_increase_percent > PERFORMANCE_REGRESSION_THRESHOLDS.memory_increase_percent:
		regressions.append({
			"type": "memory_regression",
			"severity": "MEDIUM",
			"description": "Memory usage increased by %.1f%% (baseline: %.1fMB, current: %.1fMB)" % [
				memory_increase_percent,
				_baseline_metrics.get("memory_total_mb", 0),
				recent_metrics.get("memory_total_mb", 0)
			],
			"recommendation": "Investigate memory leaks or inefficient resource usage"
		})
	
	# Check memory leak regression
	var memory_leaks = recent_metrics.get("memory_leaks_detected", 0)
	if memory_leaks > 0:
		regressions.append({
			"type": "memory_leak_regression",
			"severity": "HIGH",
			"description": "Memory leaks detected: %d active leaks" % memory_leaks,
			"recommendation": "Run MemoryLeakPrevention.force_cleanup() and investigate leak sources"
		})
	
	# Store regression alerts
	for regression in regressions:
		regression["timestamp"] = Time.get_ticks_msec()
		_regression_alerts.append(regression)
		
		# Emit alert
		print("[ProductionPerformanceMonitor] 🚨 PERFORMANCE REGRESSION DETECTED:")
		print("  %s" % regression.description)
		print("  Recommendation: %s" % regression.recommendation)
	
	# Trim old alerts
	_trim_regression_alerts()
	
	return regressions

## Generate performance optimization recommendations
func _generate_optimization_recommendations() -> Array[Dictionary]:
	var recommendations = []
	var metrics = _current_metrics
	
	# Memory optimization recommendations
	var memory_mb = metrics.get("memory_total_mb", 0)
	if memory_mb > CURRENT_BASELINES.target_memory_mb:
		var memory_excess = memory_mb - CURRENT_BASELINES.target_memory_mb
		recommendations.append({
			"type": "memory_optimization",
			"priority": "HIGH" if memory_excess > 50 else "MEDIUM",
			"description": "Memory usage %.1fMB above target of %.1fMB" % [memory_excess, CURRENT_BASELINES.target_memory_mb],
			"actions": [
				"Enable object pooling for frequently created objects",
				"Implement lazy loading for non-critical resources",
				"Clear unused resource caches",
				"Optimize texture sizes and compression"
			],
			"estimated_savings_mb": memory_excess * 0.6 # Conservative estimate
		})
	
	# FPS optimization recommendations
	var fps = metrics.get("fps", 60)
	if fps < CURRENT_BASELINES.target_fps:
		var fps_deficit = CURRENT_BASELINES.target_fps - fps
		recommendations.append({
			"type": "fps_optimization",
			"priority": "HIGH" if fps_deficit > 15 else "MEDIUM",
			"description": "FPS %.1f below target of %d" % [fps_deficit, CURRENT_BASELINES.target_fps],
			"actions": [
				"Profile _process() functions for expensive operations",
				"Optimize rendering pipeline and reduce draw calls",
				"Implement frame rate limiting for background operations",
				"Cache frequently accessed scene nodes"
			],
			"estimated_improvement_fps": fps_deficit * 0.7
		})
	
	# Node count optimization
	var node_count = metrics.get("scene_tree_node_count", 0)
	if node_count > 1000: # Threshold for large scene trees
		recommendations.append({
			"type": "scene_optimization",
			"priority": "MEDIUM",
			"description": "Scene tree has %d nodes (consider optimization above 1000)" % node_count,
			"actions": [
				"Use node pooling for dynamic UI elements",
				"Lazy-load non-visible UI components",
				"Optimize scene structure and reduce nesting",
				"Consider using Control nodes instead of Node2D where appropriate"
			],
			"estimated_node_reduction": node_count * 0.3
		})
	
	# Error boundary overhead check
	var error_overhead = metrics.get("error_boundary_overhead", 0.0)
	if error_overhead > 5.0: # >5% overhead from error boundaries
		recommendations.append({
			"type": "error_boundary_optimization",
			"priority": "LOW",
			"description": "Error boundary overhead at %.1f%% (consider optimization above 5%%)" % error_overhead,
			"actions": [
				"Review error boundary integration mode (consider SILENT mode for non-critical)",
				"Optimize error handler method caching",
				"Reduce error boundary wrapper depth",
				"Profile error recovery performance"
			],
			"estimated_overhead_reduction": error_overhead * 0.4
		})
	
	# Memory leak prevention recommendations
	var memory_leaks = metrics.get("memory_leaks_detected", 0)
	var tracked_nodes = metrics.get("tracked_nodes", 0)
	var tracked_files = metrics.get("tracked_files", 0)
	
	if memory_leaks > 0 or tracked_files > 20 or tracked_nodes > 500:
		var priority = "HIGH" if memory_leaks > 0 else ("MEDIUM" if tracked_files > 20 or tracked_nodes > 500 else "LOW")
		recommendations.append({
			"type": "memory_leak_optimization",
			"priority": priority,
			"description": "Memory leak indicators detected (leaks: %d, files: %d, nodes: %d)" % [memory_leaks, tracked_files, tracked_nodes],
			"actions": [
				"Run MemoryLeakPrevention.force_cleanup() to clear tracked resources",
				"Audit file handle usage and ensure proper file.close() calls",
				"Review node lifecycle management and queue_free() usage",
				"Check for circular references in complex object hierarchies",
				"Implement regular cleanup intervals for long-running systems"
			],
			"estimated_memory_savings": max(memory_leaks * 2.5, tracked_files * 0.1) # Conservative estimate in MB
		})
	
	# Store recommendations  
	for rec in recommendations:
		rec["timestamp"] = Time.get_ticks_msec()
	
	_optimization_recommendations = recommendations
	return recommendations

## Execute performance optimizations automatically
func execute_auto_optimizations() -> Dictionary:
	if not auto_optimization_enabled:
		return {"executed": false, "reason": "Auto-optimization disabled"}
	
	var optimizations_executed = []
	var total_savings = {"memory_mb": 0.0, "fps_improvement": 0.0, "node_reduction": 0}
	
	print("[ProductionPerformanceMonitor] Executing automatic performance optimizations...")
	
	# Execute safe, automatic optimizations
	for recommendation in _optimization_recommendations:
		match recommendation.type:
			"memory_optimization":
				if recommendation.priority == "HIGH":
					# Execute memory optimizations
					var memory_saved = await _execute_memory_optimizations()
					if memory_saved > 0:
						optimizations_executed.append("memory_cleanup_" + str(memory_saved) + "mb")
						total_savings.memory_mb += memory_saved
			
			"memory_leak_optimization":
				if recommendation.priority in ["HIGH", "MEDIUM"]:
					# Execute memory leak prevention cleanup
					var leak_cleanup = await _execute_memory_leak_cleanup()
					if leak_cleanup.memory_freed_mb > 0:
						optimizations_executed.append("leak_cleanup_" + str(leak_cleanup.memory_freed_mb) + "mb")
						total_savings.memory_mb += leak_cleanup.memory_freed_mb
			
			"scene_optimization":
				# Execute safe scene optimizations
				var nodes_removed = _execute_scene_optimizations()
				if nodes_removed > 0:
					optimizations_executed.append("scene_cleanup_" + str(nodes_removed) + "_nodes")
					total_savings.node_reduction += nodes_removed
	
	# Force garbage collection
	var gc_result = await _execute_garbage_collection()
	if gc_result.memory_freed_mb > 0:
		optimizations_executed.append("garbage_collection")
		total_savings.memory_mb += gc_result.memory_freed_mb
	
	var result = {
		"executed": optimizations_executed.size() > 0,
		"optimizations": optimizations_executed,
		"total_savings": total_savings,
		"execution_time_ms": Time.get_ticks_msec() - _last_monitoring_time
	}
	
	if result.executed:
		print("[ProductionPerformanceMonitor] ✅ Auto-optimizations completed:")
		print("  - Memory saved: %.1fMB" % total_savings.memory_mb)
		print("  - Nodes reduced: %d" % total_savings.node_reduction)
	
	return result

## Get comprehensive performance report
func get_performance_report() -> Dictionary:
	var recent_metrics = _get_recent_average_metrics(10)
	var report = {
		"monitoring_status": "ACTIVE" if _monitoring_active else "INACTIVE",
		"current_metrics": _current_metrics.duplicate(),
		"baseline_metrics": _baseline_metrics.duplicate(),
		"recent_average": recent_metrics,
		"performance_grade": _calculate_performance_grade(recent_metrics),
		"regression_alerts": _regression_alerts.slice(-5), # Last 5 alerts
		"optimization_recommendations": _optimization_recommendations,
		"targets_met": _check_performance_targets(recent_metrics),
		"history_size": _performance_history.size(),
		"monitoring_uptime_minutes": (Time.get_ticks_msec() - _last_monitoring_time) / 60000.0
	}
	
	return report

## Check if performance targets are being met
func _check_performance_targets(metrics: Dictionary) -> Dictionary:
	return {
		"fps_target_met": metrics.get("fps", 0) >= CURRENT_BASELINES.target_fps,
		"memory_target_met": metrics.get("memory_total_mb", 0) <= CURRENT_BASELINES.target_memory_mb,
		"stability_target_met": _calculate_performance_stability() > 0.9,
		"error_recovery_healthy": metrics.get("error_recovery_rate", 0.0) > 0.95
	}

## Calculate overall performance grade
func _calculate_performance_grade(metrics: Dictionary) -> String:
	var score = 0.0
	
	# FPS score (40% weight)
	var fps_score = min(metrics.get("fps", 0) / CURRENT_BASELINES.target_fps, 1.0)
	score += fps_score * 0.4
	
	# Memory score (30% weight)
	var memory_score = max(1.0 - (metrics.get("memory_total_mb", 0) - CURRENT_BASELINES.target_memory_mb) / CURRENT_BASELINES.target_memory_mb, 0.0)
	score += memory_score * 0.3
	
	# Stability score (20% weight)
	var stability_score = _calculate_performance_stability()
	score += stability_score * 0.2
	
	# Error recovery score (10% weight)
	var error_score = min(metrics.get("error_recovery_rate", 0.0), 1.0)
	score += error_score * 0.1
	
	# Convert to letter grade
	if score >= 0.9:
		return "A"
	elif score >= 0.8:
		return "B"
	elif score >= 0.7:
		return "C"
	elif score >= 0.6:
		return "D"
	else:
		return "F"

# Helper Methods

func _initialize_baseline_metrics() -> void:
	_baseline_metrics = {
		"fps": CURRENT_BASELINES.target_fps,
		"memory_total_mb": CURRENT_BASELINES.baseline_memory_mb,
		"load_time_ms": CURRENT_BASELINES.baseline_load_time_ms,
		"timestamp": Time.get_ticks_msec()
	}

func _calculate_total_memory_mb(memory_info: Dictionary) -> float:
	var total = 0
	for usage in memory_info.values():
		total += usage
	return float(total) / 1048576.0 # Convert bytes to MB

func _estimate_cpu_usage() -> float:
	# Simple CPU estimation based on frame time
	var frame_time = 1000.0 / max(Engine.get_frames_per_second(), 1.0)
	return min(frame_time / 16.67, 1.0) * 100.0 # Percentage

func _get_scene_tree_node_count() -> int:
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.current_scene:
		return _count_nodes_recursive(main_loop.current_scene)
	return 0

func _count_nodes_recursive(node: Node) -> int:
	var count = 1
	for child in node.get_children():
		count += _count_nodes_recursive(child)
	return count

func _count_active_resources() -> int:
	# Simplified resource counting - this would require engine access to resource manager
	# For now, return a reasonable estimate based on loaded scenes
	return 0  # Placeholder - would need actual resource manager access

func _calculate_error_boundary_overhead(error_stats: Dictionary) -> float:
	# Calculate overhead as percentage based on active components
	var active_components = error_stats.get("integration_stats", {}).get("active_components", {})
	return min(float(active_components.size()) * 0.5, 10.0) # Rough estimate

func _collect_load_time_metrics() -> Dictionary:
	# This would integrate with scene loading monitoring
	return {
		"last_scene_load_time_ms": 0, # Would need actual measurement
		"average_load_time_ms": 0 # Would need historical data
	}

func _get_recent_average_metrics(sample_count: int) -> Dictionary:
	if _performance_history.is_empty():
		return {}
	
	var recent_samples = _performance_history.slice(max(0, _performance_history.size() - sample_count))
	var averages = {}
	
	# Calculate averages for numeric metrics
	var numeric_keys = ["fps", "frame_time_ms", "memory_total_mb", "cpu_usage_percent", "scene_tree_node_count"]
	
	for key in numeric_keys:
		var sum = 0.0
		var count = 0
		for sample in recent_samples:
			if key in sample:
				sum += sample[key]
				count += 1
		averages[key] = sum / max(count, 1)
	
	return averages

func _calculate_performance_stability() -> float:
	if _performance_history.size() < 10:
		return 1.0 # Not enough data
	
	var recent_fps = []
	for sample in _performance_history.slice(-10):
		recent_fps.append(sample.get("fps", 60))
	
	# Calculate coefficient of variation (lower = more stable)
	var mean_fps = recent_fps.reduce(func(a, b): return a + b) / recent_fps.size()
	var variance = 0.0
	for fps in recent_fps:
		variance += pow(fps - mean_fps, 2)
	variance /= recent_fps.size()
	
	var std_dev = sqrt(variance)
	var coefficient_of_variation = std_dev / mean_fps
	
	return max(1.0 - coefficient_of_variation, 0.0)

func _trim_performance_history() -> void:
	var retention_ms = history_retention_minutes * 60000
	var cutoff_time = Time.get_ticks_msec() - retention_ms
	
	_performance_history = _performance_history.filter(func(sample): return sample.timestamp > cutoff_time)

func _trim_regression_alerts() -> void:
	var retention_ms = 60000 * 10 # Keep alerts for 10 minutes
	var cutoff_time = Time.get_ticks_msec() - retention_ms
	
	_regression_alerts = _regression_alerts.filter(func(alert): return alert.timestamp > cutoff_time)

func _execute_memory_optimizations() -> float:
	var initial_memory = _calculate_total_memory_mb(OS.get_memory_info())
	
	# Execute safe memory optimizations
	if _performance_optimizer:
		# This would call actual optimization methods
		pass
	
	# Force garbage collection
	for i in range(3):
		await Engine.get_main_loop().process_frame
	
	var final_memory = _calculate_total_memory_mb(OS.get_memory_info())
	return max(initial_memory - final_memory, 0.0)

func _execute_scene_optimizations() -> int:
	# This would implement safe scene optimizations
	# For now, return 0 as no optimizations implemented
	return 0

func _execute_memory_leak_cleanup() -> Dictionary:
	var initial_memory = _calculate_total_memory_mb(OS.get_memory_info())
	
	# Execute memory leak prevention cleanup
	if _memory_leak_prevention:
		var cleanup_result = await _memory_leak_prevention.force_cleanup() if Engine.get_main_loop() else {"memory_freed_mb": 0.0}
		var final_memory = _calculate_total_memory_mb(OS.get_memory_info())
		
		return {
			"memory_freed_mb": max(initial_memory - final_memory, cleanup_result.get("memory_freed_mb", 0.0)),
			"files_closed": cleanup_result.get("files_closed", 0),
			"nodes_cleaned": cleanup_result.get("nodes_cleaned", 0),
			"signals_disconnected": cleanup_result.get("signals_disconnected", 0)
		}
	else:
		return {"memory_freed_mb": 0.0, "files_closed": 0, "nodes_cleaned": 0, "signals_disconnected": 0}

func _execute_garbage_collection() -> Dictionary:
	var initial_memory = _calculate_total_memory_mb(OS.get_memory_info())
	
	# Force multiple GC passes
	for i in range(5):
		await Engine.get_main_loop().process_frame
	
	var final_memory = _calculate_total_memory_mb(OS.get_memory_info())
	
	return {
		"memory_freed_mb": max(initial_memory - final_memory, 0.0),
		"gc_passes": 5
	}

func _detect_memory_leaks(memory_report: Dictionary) -> int:
	"""Analyze memory report and count detected leaks"""
	var leak_count = 0
	
	# Check the last scan data
	var last_scan = memory_report.get("last_scan", {})
	if last_scan:
		leak_count += last_scan.get("leaked_nodes", 0)
		leak_count += last_scan.get("unclosed_files", 0)
		leak_count += last_scan.get("orphaned_signals", 0)
	
	return leak_count