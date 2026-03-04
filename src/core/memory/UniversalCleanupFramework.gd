@tool
class_name UniversalCleanupFramework
extends RefCounted

## Universal Cleanup Framework - Phase 3.1.2 Implementation
##
## Centralizes cleanup patterns across all 773 GDScript files in the Five Parsecs Campaign Manager.
## Provides standardized cleanup hooks and automated resource management for optimal memory usage.
## Integrates with MemoryLeakPrevention system for comprehensive memory management.

const MemoryLeakPrevention = preload("res://src/core/memory/MemoryLeakPrevention.gd")

# Cleanup patterns enumeration
enum CleanupPattern {
	SCENE_CLEANUP,        # Scene node removal and queue_free
	SIGNAL_CLEANUP,       # Signal disconnection patterns
	FILE_CLEANUP,         # File handle cleanup
	RESOURCE_CLEANUP,     # Resource unloading
	CIRCULAR_REF_CLEANUP, # Circular reference breaking
	AUTOLOAD_CLEANUP,     # Autoloaded systems cleanup
	TIMER_CLEANUP,        # Timer and tween cleanup
	THREAD_CLEANUP        # Thread and async operation cleanup
}

# Cleanup priority levels
enum CleanupPriority {
	IMMEDIATE,    # Execute immediately
	HIGH,         # Execute within 1 second
	NORMAL,       # Execute within 5 seconds
	LOW,          # Execute within 30 seconds
	DEFERRED      # Execute at next cleanup cycle
}

# Global cleanup registry
static var _cleanup_registry: Dictionary = {}
static var _cleanup_callbacks: Array[Callable] = []
static var _cleanup_timer: Timer = null
static var _emergency_cleanup_active: bool = false
static var _last_cleanup_cycle: int = 0
static var _cleanup_statistics: Dictionary = {}

# Cleanup pattern implementations
static var _pattern_handlers: Dictionary = {}

## Initialize Universal Cleanup Framework
static func initialize() -> bool:
	
	# Initialize pattern handlers
	_register_cleanup_patterns()
	
	# Setup cleanup timer
	_setup_cleanup_timer()
	
	# Initialize cleanup statistics
	_cleanup_statistics = {
		"total_cleanups": 0,
		"scene_cleanups": 0,
		"signal_cleanups": 0,
		"file_cleanups": 0,
		"resource_cleanups": 0,
		"emergency_cleanups": 0,
		"last_cleanup_time": Time.get_ticks_msec(),
		"average_cleanup_time_ms": 0.0
	}
	
	# Register with MemoryLeakPrevention
	MemoryLeakPrevention.add_leak_detection_callback(_on_memory_leak_detected)
	
	return true

## Register cleanup patterns
static func _register_cleanup_patterns() -> void:
	_pattern_handlers[CleanupPattern.SCENE_CLEANUP] = _handle_scene_cleanup
	_pattern_handlers[CleanupPattern.SIGNAL_CLEANUP] = _handle_signal_cleanup
	_pattern_handlers[CleanupPattern.FILE_CLEANUP] = _handle_file_cleanup
	_pattern_handlers[CleanupPattern.RESOURCE_CLEANUP] = _handle_resource_cleanup
	_pattern_handlers[CleanupPattern.CIRCULAR_REF_CLEANUP] = _handle_circular_ref_cleanup
	_pattern_handlers[CleanupPattern.AUTOLOAD_CLEANUP] = _handle_autoload_cleanup
	_pattern_handlers[CleanupPattern.TIMER_CLEANUP] = _handle_timer_cleanup
	_pattern_handlers[CleanupPattern.THREAD_CLEANUP] = _handle_thread_cleanup

## Setup cleanup timer
static func _setup_cleanup_timer() -> void:
	var main_loop = Engine.get_main_loop()
	if not main_loop:
		return
	
	var scene_tree = main_loop as SceneTree
	if not scene_tree:
		return
	
	if not _cleanup_timer:
		_cleanup_timer = Timer.new()
		_cleanup_timer.wait_time = 1.0  # Process cleanup queue every second
		_cleanup_timer.timeout.connect(_process_cleanup_queue)
		_cleanup_timer.autostart = true
		scene_tree.get_root().add_child(_cleanup_timer)

## CLEANUP REGISTRATION METHODS

## Register object for scene cleanup
static func register_for_scene_cleanup(node: Node, parent: Node = null, context: String = "") -> void:
	if not node:
		return
	
	var cleanup_data = {
		"pattern": CleanupPattern.SCENE_CLEANUP,
		"priority": CleanupPriority.HIGH,
		"node": weakref(node),
		"parent": weakref(parent) if parent else null,
		"context": context,
		"registration_time": Time.get_ticks_msec()
	}
	
	var cleanup_id = "scene_%d_%s" % [node.get_instance_id(), context]
	_cleanup_registry[cleanup_id] = cleanup_data
	

## Register signal for cleanup
static func register_signal_cleanup(source: Object, signal_name: String, target: Object, method_name: String) -> void:
	if not source or not target:
		return
	
	var cleanup_data = {
		"pattern": CleanupPattern.SIGNAL_CLEANUP,
		"priority": CleanupPriority.IMMEDIATE,
		"source": weakref(source),
		"signal_name": signal_name,
		"target": weakref(target),
		"method_name": method_name,
		"registration_time": Time.get_ticks_msec()
	}
	
	var cleanup_id = "signal_%d_%s_%d" % [source.get_instance_id(), signal_name, target.get_instance_id()]
	_cleanup_registry[cleanup_id] = cleanup_data
	

## Register file handle for cleanup
static func register_file_cleanup(file: FileAccess, context: String = "") -> void:
	if not file:
		return
	
	var cleanup_data = {
		"pattern": CleanupPattern.FILE_CLEANUP,
		"priority": CleanupPriority.HIGH,
		"file": file,
		"context": context,
		"registration_time": Time.get_ticks_msec()
	}
	
	var cleanup_id = "file_%d_%s" % [file.get_instance_id(), context]
	_cleanup_registry[cleanup_id] = cleanup_data
	

## Register resource for cleanup
static func register_resource_cleanup(resource: Resource, context: String = "") -> void:
	if not resource:
		return
	
	var cleanup_data = {
		"pattern": CleanupPattern.RESOURCE_CLEANUP,
		"priority": CleanupPriority.NORMAL,
		"resource": weakref(resource),
		"context": context,
		"registration_time": Time.get_ticks_msec()
	}
	
	var cleanup_id = "resource_%d_%s" % [resource.get_instance_id(), context]
	_cleanup_registry[cleanup_id] = cleanup_data
	

## Register timer for cleanup
static func register_timer_cleanup(timer: Timer, context: String = "") -> void:
	if not timer:
		return
	
	var cleanup_data = {
		"pattern": CleanupPattern.TIMER_CLEANUP,
		"priority": CleanupPriority.HIGH,
		"timer": weakref(timer),
		"context": context,
		"registration_time": Time.get_ticks_msec()
	}
	
	var cleanup_id = "timer_%d_%s" % [timer.get_instance_id(), context]
	_cleanup_registry[cleanup_id] = cleanup_data
	

## Register custom cleanup callback
static func register_cleanup_callback(callback: Callable, priority: CleanupPriority = CleanupPriority.NORMAL, context: String = "") -> void:
	if not callback.is_valid():
		return
	
	var cleanup_data = {
		"pattern": -1,  # Custom pattern
		"priority": priority,
		"callback": callback,
		"context": context,
		"registration_time": Time.get_ticks_msec()
	}
	
	var cleanup_id = "callback_%d_%s" % [Time.get_ticks_msec(), context]
	_cleanup_registry[cleanup_id] = cleanup_data
	

## CLEANUP PROCESSING

## Process cleanup queue
static func _process_cleanup_queue() -> void:
	if _emergency_cleanup_active:
		return
	
	var cleanup_start = Time.get_ticks_msec()
	var processed_count = 0
	var current_time = Time.get_ticks_msec()
	
	# Process cleanup items by priority
	for priority in [CleanupPriority.IMMEDIATE, CleanupPriority.HIGH, CleanupPriority.NORMAL]:
		for cleanup_id in _cleanup_registry.keys():
			var cleanup_data = _cleanup_registry[cleanup_id]
			
			if cleanup_data.priority == priority:
				var age = current_time - cleanup_data.registration_time
				var should_process = false
				
				match priority:
					CleanupPriority.IMMEDIATE:
						should_process = true
					CleanupPriority.HIGH:
						should_process = age >= 1000  # 1 second
					CleanupPriority.NORMAL:
						should_process = age >= 5000  # 5 seconds
					CleanupPriority.LOW:
						should_process = age >= 30000  # 30 seconds
					CleanupPriority.DEFERRED:
						should_process = age >= 60000  # 1 minute
				
				if should_process:
					await _execute_cleanup(cleanup_id, cleanup_data)
					_cleanup_registry.erase(cleanup_id)
					processed_count += 1
			
			# Limit processing time per cycle to prevent frame drops
			if Time.get_ticks_msec() - cleanup_start > 16:  # Max 16ms per frame
				break
	
	_last_cleanup_cycle = Time.get_ticks_msec()
	
	if processed_count > 0:
		var cycle_duration = _last_cleanup_cycle - cleanup_start

## Execute individual cleanup
static func _execute_cleanup(cleanup_id: String, cleanup_data: Dictionary) -> void:
	var pattern = cleanup_data.get("pattern", -1)
	
	if pattern == -1:  # Custom callback
		var callback = cleanup_data.get("callback")
		if callback and callback.is_valid():
			callback.call()
			_cleanup_statistics.total_cleanups += 1
		return
	
	if _pattern_handlers.has(pattern):
		var handler = _pattern_handlers[pattern]
		await handler.call(cleanup_data)
		_cleanup_statistics.total_cleanups += 1

## CLEANUP PATTERN HANDLERS

## Handle scene cleanup
static func _handle_scene_cleanup(cleanup_data: Dictionary) -> void:
	var node_ref = cleanup_data.get("node")
	var parent_ref = cleanup_data.get("parent")
	var context = cleanup_data.get("context", "")
	
	if not node_ref:
		return
	
	var node = node_ref.get_reference()
	if not node:
		return  # Node already freed
	
	var parent = parent_ref.get_reference() if parent_ref else node.get_parent()
	
	# Disconnect all signals first
	MemoryLeakPrevention._disconnect_all_node_signals(node)
	
	# Remove from parent
	if parent and node.get_parent() == parent:
		parent.remove_child(node)
	
	# Queue for deletion
	node.queue_free()
	
	_cleanup_statistics.scene_cleanups += 1

## Handle signal cleanup
static func _handle_signal_cleanup(cleanup_data: Dictionary) -> void:
	var source_ref = cleanup_data.get("source")
	var target_ref = cleanup_data.get("target")
	var signal_name = cleanup_data.get("signal_name")
	var method_name = cleanup_data.get("method_name")
	
	if not source_ref or not target_ref:
		return
	
	var source = source_ref.get_reference()
	var target = target_ref.get_reference()
	
	if not source or not target:
		return  # Objects already freed
	
	if source.has_signal(signal_name) and source.is_connected(signal_name, Callable(target, method_name)):
		source.disconnect(signal_name, Callable(target, method_name))
		_cleanup_statistics.signal_cleanups += 1

## Handle file cleanup
static func _handle_file_cleanup(cleanup_data: Dictionary) -> void:
	var file = cleanup_data.get("file")
	var context = cleanup_data.get("context", "")
	
	if not file:
		return
	
	if file.is_open():
		file.close()
		_cleanup_statistics.file_cleanups += 1

## Handle resource cleanup
static func _handle_resource_cleanup(cleanup_data: Dictionary) -> void:
	var resource_ref = cleanup_data.get("resource")
	var context = cleanup_data.get("context", "")
	
	if not resource_ref:
		return
	
	var resource = resource_ref.get_reference()
	if not resource:
		return  # Resource already freed
	
	# Take reference to prevent immediate deletion
	resource.take_over_path("")
	_cleanup_statistics.resource_cleanups += 1

## Handle circular reference cleanup
static func _handle_circular_ref_cleanup(cleanup_data: Dictionary) -> void:
	# Implementation for breaking circular references
	# This would be specific to detected circular reference patterns
	pass

## Handle autoload cleanup
static func _handle_autoload_cleanup(cleanup_data: Dictionary) -> void:
	# Implementation for autoload system cleanup
	# This would call shutdown methods on autoloaded systems
	var autoload_name = cleanup_data.get("autoload_name", "")
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		var autoload = tree.get_root().get_node_or_null(autoload_name)
		if autoload and autoload.has_method("cleanup"):
			autoload.cleanup()

## Handle timer cleanup
static func _handle_timer_cleanup(cleanup_data: Dictionary) -> void:
	var timer_ref = cleanup_data.get("timer")
	var context = cleanup_data.get("context", "")
	
	if not timer_ref:
		return
	
	var timer = timer_ref.get_reference()
	if not timer:
		return  # Timer already freed
	
	timer.stop()
	if timer.get_parent():
		timer.get_parent().remove_child(timer)
	timer.queue_free()
	

## Handle thread cleanup
static func _handle_thread_cleanup(cleanup_data: Dictionary) -> void:
	# Implementation for thread and async operation cleanup
	pass

## EMERGENCY AND UTILITIES

## Emergency cleanup - clear all registered items immediately
static func emergency_cleanup() -> Dictionary:
	
	_emergency_cleanup_active = true
	var cleanup_start = Time.get_ticks_msec()
	var initial_count = _cleanup_registry.size()
	
	# Process all registered cleanup items immediately
	for cleanup_id in _cleanup_registry.keys():
		var cleanup_data = _cleanup_registry[cleanup_id]
		await _execute_cleanup(cleanup_id, cleanup_data)
	
	_cleanup_registry.clear()
	
	# Reset statistics
	_cleanup_statistics.emergency_cleanups += 1
	
	var emergency_duration = Time.get_ticks_msec() - cleanup_start
	_emergency_cleanup_active = false
	
	var result = {
		"items_cleaned": initial_count,
		"duration_ms": emergency_duration,
		"timestamp": Time.get_ticks_msec()
	}
	
	return result

## Memory leak detection callback
static func _on_memory_leak_detected(current_memory: float, peak_memory: float, baseline_memory: float) -> void:
	# Trigger preventive cleanup if memory usage is concerning
	var warning_threshold = 85.0  # MB
	
	if current_memory > warning_threshold:
		await _trigger_preventive_cleanup()

## Trigger preventive cleanup
static func _trigger_preventive_cleanup() -> void:
	# Process high and immediate priority items immediately
	for cleanup_id in _cleanup_registry.keys():
		var cleanup_data = _cleanup_registry[cleanup_id]
		if cleanup_data.priority in [CleanupPriority.IMMEDIATE, CleanupPriority.HIGH]:
			await _execute_cleanup(cleanup_id, cleanup_data)
			_cleanup_registry.erase(cleanup_id)

## Get cleanup statistics
static func get_cleanup_statistics() -> Dictionary:
	return _cleanup_statistics.duplicate()

## Get registered cleanup count
static func get_registered_cleanup_count() -> int:
	return _cleanup_registry.size()

## Shutdown cleanup framework
static func shutdown() -> void:
	
	# Emergency cleanup all remaining items
	await emergency_cleanup()
	
	# Stop cleanup timer
	if _cleanup_timer:
		_cleanup_timer.queue_free()
		_cleanup_timer = null
	
	# Clear all data
	_cleanup_registry.clear()
	_cleanup_callbacks.clear()
	_pattern_handlers.clear()
	_cleanup_statistics.clear()
	
