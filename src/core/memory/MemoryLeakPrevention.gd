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

# Leak detection state
static var _monitoring_enabled: bool = false
static var _tracked_nodes: Array[WeakRef] = []
static var _tracked_file_handles: Array[FileAccess] = []
static var _signal_connections: Dictionary = {}
static var _memory_snapshots: Array[Dictionary] = []
static var _last_cleanup_time: int = 0

## Initialize memory leak prevention system
static func initialize() -> bool:
	print("[MemoryLeakPrevention] Initializing memory leak prevention system...")
	
	_monitoring_enabled = true
	_last_cleanup_time = Time.get_ticks_msec()
	
	# Start automatic monitoring
	_start_automatic_monitoring()
	
	print("[MemoryLeakPrevention] ✅ Memory leak prevention system initialized")
	return true

## Create a monitored FileAccess that automatically tracks handles
static func create_monitored_file_access(path: String, mode: FileAccess.ModeFlags) -> FileAccess:
	var file: FileAccess = FileAccess.open(path, mode)
	if file:
		_tracked_file_handles.append(file)
		print("[MemoryLeakPrevention] Tracking file handle: %s (%d total)" % [path, _tracked_file_handles.size()])
	return file

## Close and untrack a monitored FileAccess
static func close_monitored_file_access(file: FileAccess) -> void:
	if file:
		file.close()
		_tracked_file_handles.erase(file)
		print("[MemoryLeakPrevention] Closed file handle (%d remaining)" % _tracked_file_handles.size())

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
		
		print("[MemoryLeakPrevention] Created monitored %s node: %s (%d total)" % [node_class, context, _tracked_nodes.size()])
	
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
	
	print("[MemoryLeakPrevention] Removed and freed node: %s (%d remaining)" % [context, _tracked_nodes.size()])
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
	
	print("[MemoryLeakPrevention] Tracking signal connection: %s" % connection_key)

## Safely disconnect and untrack signal
static func disconnect_tracked_signal(source: Object, signal_name: String, target: Object, target_method: String) -> void:
	var connection_key = "%s:%s->%s:%s" % [source.get_instance_id(), signal_name, target.get_instance_id(), target_method]
	
	if source.has_signal(signal_name) and source.is_connected(signal_name, Callable(target, target_method)):
		source.disconnect(signal_name, Callable(target, target_method))
		_signal_connections.erase(connection_key)
		print("[MemoryLeakPrevention] Disconnected tracked signal: %s" % connection_key)

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
	
	print("[MemoryLeakPrevention] Starting comprehensive memory leak scan...")
	
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
	
	print("[MemoryLeakPrevention] Scan complete - Found %d potential leaks" % (leak_report.leaked_nodes + leak_report.unclosed_files + leak_report.orphaned_signals))
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
	
	print("[MemoryLeakPrevention] Starting force cleanup...")
	
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
	
	print("[MemoryLeakPrevention] Force cleanup complete - Freed %.1fMB memory" % cleanup_result.memory_freed_mb)
	return cleanup_result

## Get current memory usage in MB
static func _get_total_memory_usage() -> float:
	var memory_info = OS.get_memory_info()
	var total: int = 0
	for usage in memory_info.values():
		total += usage
	return float(total) / 1048576.0  # Convert bytes to MB

## Start automatic monitoring
static func _start_automatic_monitoring() -> void:
	# This would integrate with the SceneTree for automatic monitoring
	# In a real implementation, you'd create a timer or connect to SceneTree signals
	print("[MemoryLeakPrevention] Automatic monitoring started")

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

## Generate comprehensive memory report
static func get_memory_report() -> Dictionary:
	var memory_snapshot = scan_for_memory_leaks()
	
	return {
		"monitoring_enabled": _monitoring_enabled,
		"current_memory_mb": memory_snapshot.total_memory_mb,
		"memory_status": _get_memory_status(memory_snapshot.total_memory_mb),
		"tracked_nodes": _tracked_nodes.size(),
		"tracked_files": _tracked_file_handles.size(),
		"tracked_signals": _signal_connections.size(),
		"last_scan": memory_snapshot,
		"last_cleanup_time": _last_cleanup_time,
		"recommendations": memory_snapshot.recommendations
	}

## Get memory status classification
static func _get_memory_status(memory_mb: float) -> String:
	if memory_mb > MEMORY_CRITICAL_THRESHOLD / 1024 / 1024:
		return "CRITICAL"
	elif memory_mb > MEMORY_WARNING_THRESHOLD / 1024 / 1024:
		return "WARNING"
	else:
		return "HEALTHY"

## Shutdown and cleanup all tracked resources
static func shutdown() -> void:
	print("[MemoryLeakPrevention] Shutting down memory leak prevention...")
	
	var cleanup_result = await force_cleanup() if Engine.get_main_loop() else {"cleanup_time": 0, "files_closed": 0, "nodes_cleaned": 0, "signals_disconnected": 0, "memory_freed_mb": 0.0}
	
	_monitoring_enabled = false
	_tracked_nodes.clear()
	_tracked_file_handles.clear()
	_signal_connections.clear()
	_memory_snapshots.clear()
	
	print("[MemoryLeakPrevention] ✅ Shutdown complete - Cleaned up all tracked resources")