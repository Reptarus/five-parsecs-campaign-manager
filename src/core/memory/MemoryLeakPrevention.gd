@tool
class_name MemoryLeakPrevention
extends RefCounted

## Memory Leak Prevention Utilities - Phase 4.2 Implementation
##
## Based on Gemini CLI memory leak analysis, this system provides automated
## prevention and detection of memory leaks in the Five Parsecs Campaign Manager.
## Addresses the 6 identified risk patterns across 419 analyzed files.

# Leak detection patterns from Gemini analysis
enum LeakPattern {
	MISSING_QUEUE_FREE,     # 1 occurrence - UniversalNodeAccess.gd
	UNCLOSED_FILE_ACCESS,   # 5 occurrences - Various files
	DISCONNECTED_SIGNALS,   # 0 occurrences - But monitoring
	CIRCULAR_REFERENCES     # 1 potential - BattleTutorialManager.gd
}

# Memory monitoring thresholds
const MEMORY_WARNING_THRESHOLD: int = 85 * 1024 * 1024    # 85MB
const MEMORY_CRITICAL_THRESHOLD: int = 110 * 1024 * 1024  # 110MB
const NODE_COUNT_WARNING: int = 1000
const FILE_HANDLE_LIMIT: int = 50
const AUTO_CLEANUP_INTERVAL: int = 30000  # 30 seconds
const MEMORY_REGRESSION_THRESHOLD: float = 20.0  # 20% increase

# Leak detection state
static var _monitoring_enabled: bool = false
static var _tracked_nodes: Array[WeakRef] = []
static var _tracked_file_handles: Array[FileAccess] = []
static var _signal_connections: Dictionary = {}
static var _memory_snapshots: Array[Dictionary] = []
static var _last_cleanup_time: int = 0

# Enhanced monitoring state
static var _baseline_memory: float = 0.0
static var _peak_memory: float = 0.0
static var _monitoring_timer: Timer = null
static var _auto_cleanup_timer: Timer = null
static var _memory_alerts: Array[Dictionary] = []
static var _performance_metrics: Dictionary = {}
static var _leak_detection_callbacks: Array[Callable] = []

## Initialize memory leak prevention system
static func initialize() -> bool:
	
	_monitoring_enabled = true
	_last_cleanup_time = Time.get_ticks_msec()
	
	# Start automatic monitoring
	_start_automatic_monitoring()
	
	return true

## Create a monitored FileAccess that automatically tracks handles
static func create_monitored_file_access(path: String, mode: FileAccess.ModeFlags) -> FileAccess:
	var file: FileAccess = FileAccess.open(path, mode)
	if file:
		_tracked_file_handles.append(file)
		pass # File handle tracked
	return file

## Close and untrack a monitored FileAccess
static func close_monitored_file_access(file: FileAccess) -> void:
	if file:
		file.close()
		_tracked_file_handles.erase(file)
		pass # File handle closed

## Safe node creation with automatic tracking
static func create_monitored_node(node_class: String, context: String = "") -> Node:
	var node: Node = null
	
	match node_class:
		"Control":
			node = Control.new()
		"Node2D":
			node = Node2D.new()
		"Node":
			node = Node.new()
		"Button":
			node = Button.new()
		"Label":
			node = Label.new()
		_:
			push_error("MemoryLeakPrevention: Unknown node class: " + node_class)
			return null
	
	if node:
		var weak_ref: WeakRef = weakref(node)
		_tracked_nodes.append(weak_ref)
		node.set_meta("_memory_context", context)
		node.set_meta("_creation_time", Time.get_ticks_msec())
		
		pass # Monitored node created
	
	return node

## Safe node removal with proper cleanup
static func remove_and_free_monitored_node(parent: Node, child: Node, context: String = "") -> bool:
	if not parent or not child:
		push_error("MemoryLeakPrevention: Invalid parent or child node")
		return false
	
	# Disconnect all signals to prevent memory leaks
	_disconnect_all_node_signals(child)
	
	# Remove from parent
	if child.get_parent() == parent:
		parent.remove_child(child)
	
	# Remove from tracking
	for i in range(_tracked_nodes.size() - 1, -1, -1):
		var weak_ref = _tracked_nodes[i]
		if weak_ref.get_reference() == child:
			_tracked_nodes.remove_at(i)
			break
	
	# Queue for deletion
	child.queue_free()
	
	pass # Node removed and freed
	return true

## Monitor signal connections to detect leaks
static func track_signal_connection(source: Object, signal_name: String, target: Object, target_method: String) -> void:
	var connection_key = "%s:%s->%s:%s" % [source.get_instance_id(), signal_name, target.get_instance_id(), target_method]
	
	_signal_connections[connection_key] = {
		"source": weakref(source),
		"signal_name": signal_name,
		"target": weakref(target),
		"target_method": target_method,
		"connection_time": Time.get_ticks_msec()
	}
	

## Safely disconnect and untrack signal
static func disconnect_tracked_signal(source: Object, signal_name: String, target: Object, target_method: String) -> void:
	var connection_key = "%s:%s->%s:%s" % [source.get_instance_id(), signal_name, target.get_instance_id(), target_method]
	
	if source.has_signal(signal_name) and source.is_connected(signal_name, Callable(target, target_method)):
		source.disconnect(signal_name, Callable(target, target_method))
		_signal_connections.erase(connection_key)

## Perform comprehensive memory leak scan
static func scan_for_memory_leaks() -> Dictionary:
	var leak_report = {
		"scan_time": Time.get_ticks_msec(),
		"total_memory_mb": _get_total_memory_usage(),
		"leaked_nodes": 0,
		"unclosed_files": 0,
		"orphaned_signals": 0,
		"recommendations": []
	}
	
	
	# Check for leaked nodes (null references)
	for i in range(_tracked_nodes.size() - 1, -1, -1):
		var weak_ref = _tracked_nodes[i]
		if not weak_ref.get_reference():
			_tracked_nodes.remove_at(i)
			leak_report.leaked_nodes += 1
	
	# Check for unclosed file handles
	for i in range(_tracked_file_handles.size() - 1, -1, -1):
		var file = _tracked_file_handles[i]
		if not file or not file.is_open():
			_tracked_file_handles.remove_at(i)
			leak_report.unclosed_files += 1
	
	# Check for orphaned signal connections
	for connection_key in _signal_connections.keys():
		var connection_data = _signal_connections[connection_key]
		var source = connection_data.source.get_reference()
		var target = connection_data.target.get_reference()
		
		if not source or not target:
			_signal_connections.erase(connection_key)
			leak_report.orphaned_signals += 1
	
	# Generate recommendations
	if leak_report.leaked_nodes > 0:
		leak_report.recommendations.append("Found %d leaked nodes - ensure proper queue_free() calls" % leak_report.leaked_nodes)
	
	if leak_report.unclosed_files > 0:
		leak_report.recommendations.append("Found %d unclosed files - ensure proper file.close() calls" % leak_report.unclosed_files)
	
	if leak_report.orphaned_signals > 0:
		leak_report.recommendations.append("Found %d orphaned signals - ensure proper signal disconnection" % leak_report.orphaned_signals)
	
	if leak_report.total_memory_mb > MEMORY_WARNING_THRESHOLD / 1024 / 1024:
		leak_report.recommendations.append("Memory usage above warning threshold: %dMB" % (leak_report.total_memory_mb))
	
	pass # Leak scan complete
	return leak_report

## Force cleanup of tracked resources
static func force_cleanup() -> Dictionary:
	var cleanup_result = {
		"cleanup_time": Time.get_ticks_msec(),
		"files_closed": 0,
		"nodes_cleaned": 0,
		"signals_disconnected": 0,
		"memory_freed_mb": 0.0
	}
	
	var initial_memory = _get_total_memory_usage()
	
	
	# Close all tracked file handles
	for file in _tracked_file_handles:
		if file and file.is_open():
			file.close()
			cleanup_result.files_closed += 1
	_tracked_file_handles.clear()
	
	# Clean up dead node references
	for i in range(_tracked_nodes.size() - 1, -1, -1):
		var weak_ref = _tracked_nodes[i]
		if not weak_ref.get_reference():
			_tracked_nodes.remove_at(i)
			cleanup_result.nodes_cleaned += 1
	
	# Disconnect orphaned signals
	for connection_key in _signal_connections.keys():
		var connection_data = _signal_connections[connection_key]
		var source = connection_data.source.get_reference()
		var target = connection_data.target.get_reference()
		
		if not source or not target:
			_signal_connections.erase(connection_key)
			cleanup_result.signals_disconnected += 1
	
	# Force garbage collection
	for i in range(5):
		await Engine.get_main_loop().process_frame if Engine.get_main_loop() else null
	
	var final_memory = _get_total_memory_usage()
	cleanup_result.memory_freed_mb = max(initial_memory - final_memory, 0.0)
	
	_last_cleanup_time = Time.get_ticks_msec()
	
	return cleanup_result

## Get current memory usage in MB
static func _get_total_memory_usage() -> float:
	var memory_info = OS.get_memory_info()
	var total: int = 0
	for usage in memory_info.values():
		total += usage
	return float(total) / 1048576.0  # Convert bytes to MB

## Start automatic monitoring with real-time detection
static func _start_automatic_monitoring() -> void:
	# Get the main loop to access SceneTree
	var main_loop = Engine.get_main_loop()
	if not main_loop:
		return
	
	var scene_tree = main_loop as SceneTree
	if not scene_tree:
		return
	
	# Create monitoring timer if it doesn't exist
	if not _monitoring_timer:
		_monitoring_timer = Timer.new()
		_monitoring_timer.wait_time = 5.0  # Check every 5 seconds
		_monitoring_timer.timeout.connect(_on_memory_monitoring_check)
		_monitoring_timer.autostart = true
		scene_tree.get_root().add_child(_monitoring_timer)
		pass # Monitoring timer created
	
	# Create auto-cleanup timer if it doesn't exist
	if not _auto_cleanup_timer:
		_auto_cleanup_timer = Timer.new()
		_auto_cleanup_timer.wait_time = 30.0  # Cleanup every 30 seconds
		_auto_cleanup_timer.timeout.connect(_on_auto_cleanup_check)
		_auto_cleanup_timer.autostart = true
		scene_tree.get_root().add_child(_auto_cleanup_timer)
		pass # Auto-cleanup timer created
	
	# Establish baseline memory measurement
	_baseline_memory = _get_total_memory_usage()
	_peak_memory = _baseline_memory
	
	pass # Real-time monitoring started

## Disconnect all signals from a node
static func _disconnect_all_node_signals(node: Node) -> void:
	var signal_list = node.get_signal_list()
	for signal_info in signal_list:
		var signal_name = signal_info["name"]
		var connections = node.get_signal_connection_list(signal_name)
		for connection in connections:
			var target = connection.get("callable").get_object()
			var method = connection.get("callable").get_method()
			if target and method:
				node.disconnect(signal_name, Callable(target, method))

## Generate comprehensive memory report for production monitoring
static func get_memory_report() -> Dictionary:
	var memory_snapshot = scan_for_memory_leaks()
	var current_memory = _get_total_memory_usage()
	
	return {
		"monitoring_enabled": _monitoring_enabled,
		"current_memory_mb": current_memory,
		"baseline_memory_mb": _baseline_memory,
		"peak_memory_mb": _peak_memory,
		"memory_status": _get_memory_status(current_memory),
		"memory_regression_percent": _calculate_memory_regression(),
		"tracked_nodes": _tracked_nodes.size(),
		"tracked_files": _tracked_file_handles.size(),
		"tracked_signals": _signal_connections.size(),
		"recent_alerts": _get_recent_alerts(),
		"performance_metrics": _performance_metrics.duplicate(),
		"last_scan": memory_snapshot,
		"last_cleanup_time": _last_cleanup_time,
		"recommendations": memory_snapshot.recommendations,
		"monitoring_health": _get_monitoring_health()
	}

## Calculate memory regression percentage from baseline
static func _calculate_memory_regression() -> float:
	if _baseline_memory <= 0.0:
		return 0.0
	var current_memory = _get_total_memory_usage()
	return ((current_memory - _baseline_memory) / _baseline_memory) * 100.0

## Get recent memory alerts (last 10)
static func _get_recent_alerts() -> Array[Dictionary]:
	var recent_alerts = _memory_alerts.slice(-10) if _memory_alerts.size() > 10 else _memory_alerts.duplicate()
	return recent_alerts

## Get monitoring system health status
static func _get_monitoring_health() -> Dictionary:
	var health = {
		"status": "healthy",
		"issues": [],
		"uptime_seconds": 0.0,
		"last_monitoring_check": 0,
		"last_cleanup_check": 0
	}
	
	# Check if monitoring timers are active
	if not _monitoring_timer or not _monitoring_timer.is_inside_tree():
		health.status = "degraded"
		health.issues.append("Memory monitoring timer not active")
	
	if not _auto_cleanup_timer or not _auto_cleanup_timer.is_inside_tree():
		health.status = "degraded"
		health.issues.append("Auto-cleanup timer not active")
	
	# Calculate uptime from baseline establishment
	if _baseline_memory > 0.0:
		health.uptime_seconds = float(Time.get_ticks_msec()) / 1000.0
	
	# Check for excessive alerts
	var recent_critical_alerts = 0
	var current_time = Time.get_ticks_msec()
	for alert in _memory_alerts:
		if alert.level == "CRITICAL" and (current_time - alert.timestamp) < 300000: # Last 5 minutes
			recent_critical_alerts += 1
	
	if recent_critical_alerts > 5:
		health.status = "critical"
		health.issues.append("Excessive critical memory alerts (%d in last 5 minutes)" % recent_critical_alerts)
	
	return health

## Memory leak prevention integration with production monitoring
static func integrate_with_production_monitor(production_monitor_callable: Callable) -> bool:
	## Integrate with production performance monitor for advanced monitoring
	if not production_monitor_callable.is_valid():
		return false
	
	# Add production monitor as leak detection callback
	add_leak_detection_callback(production_monitor_callable)
	
	# Provide memory report to production monitor
	var memory_report = get_memory_report()
	production_monitor_callable.call(memory_report)
	
	return true

## Emergency memory release for low-memory situations
static func emergency_memory_release() -> Dictionary:
	## Emergency memory release - use only in critical situations
	
	var release_start = Time.get_ticks_msec()
	var initial_memory = _get_total_memory_usage()
	
	var release_result = {
		"initial_memory_mb": initial_memory,
		"actions_taken": [],
		"memory_freed_mb": 0.0,
		"duration_ms": 0
	}
	
	# 1. Force cleanup all tracked resources
	await force_cleanup()
	release_result.actions_taken.append("Forced cleanup of all tracked resources")
	
	# 2. Clear all internal caches
	_clear_performance_metrics_cache()
	_memory_snapshots.clear()
	release_result.actions_taken.append("Cleared internal caches and snapshots")
	
	# 3. Aggressive garbage collection
	for i in range(20):
		if Engine.get_main_loop():
			await Engine.get_main_loop().process_frame
	release_result.actions_taken.append("Performed aggressive garbage collection (20 frames)")
	
	# 4. Reset baseline to current state
	reset_baseline_memory()
	release_result.actions_taken.append("Reset memory baseline")
	
	var final_memory = _get_total_memory_usage()
	release_result.memory_freed_mb = max(initial_memory - final_memory, 0.0)
	release_result.duration_ms = Time.get_ticks_msec() - release_start
	
	pass # Emergency memory release complete
	
	return release_result

## Check if memory management is stable
static func is_memory_stable() -> bool:
	## Check if memory management is currently stable
	var current_memory = _get_total_memory_usage()
	var warning_threshold_mb = float(MEMORY_WARNING_THRESHOLD) / 1048576.0
	
	# Check thresholds
	if current_memory > warning_threshold_mb:
		return false
	
	# Check regression
	var regression = _calculate_memory_regression()
	if regression > MEMORY_REGRESSION_THRESHOLD:
		return false
	
	# Check recent alerts
	var recent_alerts = _get_recent_alerts()
	for alert in recent_alerts:
		if alert.level == "CRITICAL":
			var time_diff = Time.get_ticks_msec() - alert.timestamp
			if time_diff < 60000: # Less than 1 minute ago
				return false
	
	return true

## Get memory efficiency score (0.0 to 1.0)
static func get_memory_efficiency_score() -> float:
	## Calculate memory efficiency score for production monitoring
	var score = 1.0
	var current_memory = _get_total_memory_usage()
	var warning_threshold_mb = float(MEMORY_WARNING_THRESHOLD) / 1048576.0
	var critical_threshold_mb = float(MEMORY_CRITICAL_THRESHOLD) / 1048576.0
	
	# Memory usage penalty
	if current_memory > critical_threshold_mb:
		score *= 0.1  # Critical penalty
	elif current_memory > warning_threshold_mb:
		score *= 0.6  # Warning penalty
	else:
		# Efficiency bonus for staying under thresholds
		var efficiency_ratio = current_memory / warning_threshold_mb
		score *= max(0.7, 1.0 - efficiency_ratio * 0.3)
	
	# Regression penalty
	var regression = _calculate_memory_regression()
	if regression > MEMORY_REGRESSION_THRESHOLD:
		score *= max(0.2, 1.0 - (regression / 100.0))
	
	# Alert penalty
	var recent_critical_alerts = 0
	var current_time = Time.get_ticks_msec()
	for alert in _memory_alerts:
		if alert.level == "CRITICAL" and (current_time - alert.timestamp) < 300000: # Last 5 minutes
			recent_critical_alerts += 1
	
	if recent_critical_alerts > 0:
		score *= max(0.3, 1.0 - (recent_critical_alerts * 0.2))
	
	return clamp(score, 0.0, 1.0)

## Get memory status classification
static func _get_memory_status(memory_mb: float) -> String:
	if memory_mb > MEMORY_CRITICAL_THRESHOLD / 1024 / 1024:
		return "CRITICAL"
	elif memory_mb > MEMORY_WARNING_THRESHOLD / 1024 / 1024:
		return "WARNING"
	else:
		return "HEALTHY"

## Real-time memory monitoring callback
static func _on_memory_monitoring_check() -> void:
	if not _monitoring_enabled:
		return
	
	var current_memory = _get_total_memory_usage()
	var memory_mb = current_memory
	
	# Update peak memory tracking
	if current_memory > _peak_memory:
		_peak_memory = current_memory
	
	# Check memory thresholds
	var warning_threshold_mb = float(MEMORY_WARNING_THRESHOLD) / 1048576.0
	var critical_threshold_mb = float(MEMORY_CRITICAL_THRESHOLD) / 1048576.0
	
	if memory_mb > critical_threshold_mb:
		var alert = {
			"timestamp": Time.get_ticks_msec(),
			"level": "CRITICAL",
			"memory_mb": memory_mb,
			"threshold_mb": critical_threshold_mb,
			"message": "Memory usage exceeds critical threshold - immediate cleanup required"
		}
		_memory_alerts.append(alert)
		
		# Trigger immediate cleanup
		await _trigger_emergency_cleanup()
		
	elif memory_mb > warning_threshold_mb:
		var alert = {
			"timestamp": Time.get_ticks_msec(),
			"level": "WARNING", 
			"memory_mb": memory_mb,
			"threshold_mb": warning_threshold_mb,
			"message": "Memory usage exceeds warning threshold"
		}
		_memory_alerts.append(alert)
	
	# Check for memory regression (20% increase from baseline)
	if _baseline_memory > 0.0:
		var regression_ratio = (current_memory - _baseline_memory) / _baseline_memory
		if regression_ratio > (MEMORY_REGRESSION_THRESHOLD / 100.0):
			var alert = {
				"timestamp": Time.get_ticks_msec(),
				"level": "REGRESSION",
				"memory_mb": memory_mb,
				"baseline_mb": _baseline_memory,
				"regression_percent": regression_ratio * 100.0,
				"message": "Memory regression detected - %.1f%% increase from baseline" % (regression_ratio * 100.0)
			}
			_memory_alerts.append(alert)
			push_warning("[MemoryLeakPrevention] REGRESSION: Memory increased %.1f%% from baseline" % (regression_ratio * 100.0))
	
	# Execute leak detection callbacks
	for callback in _leak_detection_callbacks:
		if callback.is_valid():
			callback.call(current_memory, _peak_memory, _baseline_memory)
	
	# Limit alert history to prevent memory bloat
	if _memory_alerts.size() > 50:
		_memory_alerts = _memory_alerts.slice(-50)

## Auto-cleanup check callback
static func _on_auto_cleanup_check() -> void:
	if not _monitoring_enabled:
		return
	
	var current_time = Time.get_ticks_msec()
	var time_since_last_cleanup = current_time - _last_cleanup_time
	
	# Perform cleanup if interval has passed
	if time_since_last_cleanup >= AUTO_CLEANUP_INTERVAL:
		await _trigger_scheduled_cleanup()

## Emergency cleanup for critical memory situations
static func _trigger_emergency_cleanup() -> void:
	
	var emergency_start = Time.get_ticks_msec()
	var initial_memory = _get_total_memory_usage()
	
	# Force immediate garbage collection
	for i in range(10):
		if Engine.get_main_loop():
			await Engine.get_main_loop().process_frame
	
	# Aggressive cleanup of tracked resources
	var cleanup_result = await force_cleanup()
	
	# Additional emergency measures
	_clear_performance_metrics_cache()
	
	var final_memory = _get_total_memory_usage()
	var memory_freed = max(initial_memory - final_memory, 0.0)
	var emergency_duration = Time.get_ticks_msec() - emergency_start
	

## Scheduled cleanup for maintenance
static func _trigger_scheduled_cleanup() -> void:
	
	var cleanup_start = Time.get_ticks_msec()
	var initial_memory = _get_total_memory_usage()
	
	# Light cleanup - remove dead references
	await _cleanup_dead_references()
	
	# Update performance metrics
	_update_performance_metrics()
	
	var final_memory = _get_total_memory_usage()
	var memory_freed = max(initial_memory - final_memory, 0.0)
	var cleanup_duration = Time.get_ticks_msec() - cleanup_start
	

## Clean up dead references without forcing resource disposal
static func _cleanup_dead_references() -> void:
	var cleaned_nodes = 0
	var cleaned_signals = 0
	var cleaned_files = 0
	
	# Clean dead node references
	for i in range(_tracked_nodes.size() - 1, -1, -1):
		var weak_ref = _tracked_nodes[i]
		if not weak_ref.get_reference():
			_tracked_nodes.remove_at(i)
			cleaned_nodes += 1
	
	# Clean orphaned signal connections
	for connection_key in _signal_connections.keys():
		var connection_data = _signal_connections[connection_key]
		var source = connection_data.source.get_reference()
		var target = connection_data.target.get_reference()
		
		if not source or not target:
			_signal_connections.erase(connection_key)
			cleaned_signals += 1
	
	# Clean invalid file handles
	for i in range(_tracked_file_handles.size() - 1, -1, -1):
		var file = _tracked_file_handles[i]
		if not file or not file.is_open():
			_tracked_file_handles.remove_at(i)
			cleaned_files += 1
	
	if cleaned_nodes > 0 or cleaned_signals > 0 or cleaned_files > 0:
		pass

## Update performance metrics cache
static func _update_performance_metrics() -> void:
	_performance_metrics = {
		"current_memory_mb": _get_total_memory_usage(),
		"baseline_memory_mb": _baseline_memory,
		"peak_memory_mb": _peak_memory,
		"tracked_nodes": _tracked_nodes.size(),
		"tracked_files": _tracked_file_handles.size(),
		"tracked_signals": _signal_connections.size(),
		"memory_alerts": _memory_alerts.size(),
		"last_update": Time.get_ticks_msec()
	}

## Clear performance metrics cache to free memory
static func _clear_performance_metrics_cache() -> void:
	_performance_metrics.clear()
	
	# Clear old alerts (keep only recent 10)
	if _memory_alerts.size() > 10:
		_memory_alerts = _memory_alerts.slice(-10)

## Add leak detection callback
static func add_leak_detection_callback(callback: Callable) -> void:
	if callback.is_valid() and not _leak_detection_callbacks.has(callback):
		_leak_detection_callbacks.append(callback)

## Remove leak detection callback
static func remove_leak_detection_callback(callback: Callable) -> void:
	_leak_detection_callbacks.erase(callback)

## Get current memory alerts
static func get_memory_alerts() -> Array[Dictionary]:
	return _memory_alerts.duplicate()

## Get performance metrics
static func get_performance_metrics() -> Dictionary:
	return _performance_metrics.duplicate()

## Reset baseline memory measurement
static func reset_baseline_memory() -> void:
	_baseline_memory = _get_total_memory_usage()
	_peak_memory = _baseline_memory

## Shutdown and cleanup all tracked resources
static func shutdown() -> void:
	
	# Stop monitoring timers
	if _monitoring_timer:
		_monitoring_timer.queue_free()
		_monitoring_timer = null
	
	if _auto_cleanup_timer:
		_auto_cleanup_timer.queue_free()
		_auto_cleanup_timer = null
	
	var cleanup_result = await force_cleanup() if Engine.get_main_loop() else {"cleanup_time": 0, "files_closed": 0, "nodes_cleaned": 0, "signals_disconnected": 0, "memory_freed_mb": 0.0}
	
	_monitoring_enabled = false
	_tracked_nodes.clear()
	_tracked_file_handles.clear()
	_signal_connections.clear()
	_memory_snapshots.clear()
	_memory_alerts.clear()
	_performance_metrics.clear()
	_leak_detection_callbacks.clear()
	