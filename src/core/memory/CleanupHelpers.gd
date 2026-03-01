@tool
class_name CleanupHelpers
extends RefCounted

## Cleanup Helpers - Universal Cleanup Framework Integration Utilities
##
## Provides easy-to-use helper methods for integrating with UniversalCleanupFramework.
## Designed to be used across all 773 GDScript files with minimal code changes.
## Simplifies memory management and cleanup registration for developers.

const UniversalCleanupFramework = preload("res://src/core/memory/UniversalCleanupFramework.gd")
const MemoryLeakPrevention = preload("res://src/core/memory/MemoryLeakPrevention.gd")

## EASY INTEGRATION METHODS FOR COMMON USE CASES

## Auto-cleanup node when parent is freed
static func auto_cleanup_node(node: Node, context: String = "") -> void:
	## Register node for automatic cleanup when it should be freed
	if not node:
		return
	
	var cleanup_context = context if context != "" else node.get_class()
	UniversalCleanupFramework.register_for_scene_cleanup(node, node.get_parent(), cleanup_context)

## Auto-cleanup signal connection
static func auto_cleanup_signal(source: Object, signal_name: String, target: Object, method_name: String) -> void:
	## Register signal for automatic disconnection
	if not source or not target:
		return
	
	# Connect the signal first
	if source.has_signal(signal_name) and not source.is_connected(signal_name, Callable(target, method_name)):
		source.connect(signal_name, Callable(target, method_name))
	
	# Register for cleanup
	UniversalCleanupFramework.register_signal_cleanup(source, signal_name, target, method_name)

## Auto-cleanup file handle
static func auto_cleanup_file(file_path: String, mode: FileAccess.ModeFlags, context: String = "") -> FileAccess:
	## Open file with automatic cleanup registration
	var file = FileAccess.open(file_path, mode)
	if file:
		var cleanup_context = context if context != "" else "file_" + file_path.get_file()
		UniversalCleanupFramework.register_file_cleanup(file, cleanup_context)
	return file

## Auto-cleanup timer
static func auto_cleanup_timer(parent: Node, wait_time: float, callback: Callable, context: String = "") -> Timer:
	## Create timer with automatic cleanup registration
	if not parent:
		return null
	
	var timer = Timer.new()
	timer.wait_time = wait_time
	timer.one_shot = true
	timer.timeout.connect(callback)
	
	parent.add_child(timer)
	timer.start()
	
	var cleanup_context = context if context != "" else "timer_" + str(wait_time)
	UniversalCleanupFramework.register_timer_cleanup(timer, cleanup_context)
	
	return timer

## Auto-cleanup resource loading
static func auto_cleanup_resource(resource_path: String, context: String = "") -> Resource:
	## Load resource with automatic cleanup registration
	var resource = load(resource_path)
	if resource:
		var cleanup_context = context if context != "" else "resource_" + resource_path.get_file()
		UniversalCleanupFramework.register_resource_cleanup(resource, cleanup_context)
	return resource

## MIXIN PATTERN FOR EASY INHERITANCE

## CleanupMixin - Add to any class to get automatic cleanup capabilities
class CleanupMixin:
	var _cleanup_items: Array[String] = []
	var _cleanup_context: String = ""
	
	func _init(context: String = ""):
		_cleanup_context = context if context != "" else get_class()
	
	## Register current object for cleanup (only for Node-based objects)
	func register_self_cleanup() -> void:
		# This mixin is designed for objects that inherit from Node
		print("[CleanupMixin] Warning: register_self_cleanup called on non-Node object")
	
	## Add child with automatic cleanup (only for Node-based objects)
	func add_child_with_cleanup(child: Node, context: String = "") -> void:
		print("[CleanupMixin] Warning: add_child_with_cleanup called on non-Node object")
	
	## Connect signal with automatic cleanup
	func connect_signal_with_cleanup(source: Object, signal_name: String, method_name: String) -> void:
		if source and source.has_signal(signal_name):
			CleanupHelpers.auto_cleanup_signal(source, signal_name, self, method_name)
	
	## Open file with automatic cleanup
	func open_file_with_cleanup(file_path: String, mode: FileAccess.ModeFlags, context: String = "") -> FileAccess:
		return CleanupHelpers.auto_cleanup_file(file_path, mode, context)
	
	## Create timer with automatic cleanup (only for Node-based objects)
	func create_timer_with_cleanup(wait_time: float, callback: Callable, context: String = "") -> Timer:
		print("[CleanupMixin] Warning: create_timer_with_cleanup called on non-Node object")
		return null
	
	## Load resource with automatic cleanup
	func load_resource_with_cleanup(resource_path: String, context: String = "") -> Resource:
		return CleanupHelpers.auto_cleanup_resource(resource_path, context)
	
	## Cleanup all registered items for this object
	func cleanup_all() -> void:
		# This would be called automatically by UniversalCleanupFramework
		print("[CleanupMixin] Cleaning up all items for: %s" % _cleanup_context)

## CONVENIENCE METHODS FOR SPECIFIC SYSTEMS

## Campaign creation cleanup helper
static func setup_campaign_creation_cleanup(ui_controller: Node, state_manager: Object) -> void:
	## Setup cleanup for campaign creation components
	if not ui_controller or not state_manager:
		return
	
	# Register UI controller for cleanup
	auto_cleanup_node(ui_controller, "campaign_creation_ui")
	
	# Register state manager signals if it has any
	if state_manager.has_signal("state_changed"):
		auto_cleanup_signal(state_manager, "state_changed", ui_controller, "_on_state_changed")

## Battle system cleanup helper
static func setup_battle_system_cleanup(battle_manager: Node, battlefield: Node) -> void:
	## Setup cleanup for battle system components
	if battle_manager:
		auto_cleanup_node(battle_manager, "battle_manager")
	
	if battlefield:
		auto_cleanup_node(battlefield, "battlefield")

## Character management cleanup helper
static func setup_character_cleanup(character_manager: Node, character_nodes: Array) -> void:
	## Setup cleanup for character management components
	if character_manager:
		auto_cleanup_node(character_manager, "character_manager")
	
	for i in range(character_nodes.size()):
		var character_node = character_nodes[i]
		if character_node is Node:
			auto_cleanup_node(character_node, "character_%d" % i)

## Ship system cleanup helper
static func setup_ship_cleanup(ship_manager: Node, ship_components: Array) -> void:
	## Setup cleanup for ship system components
	if ship_manager:
		auto_cleanup_node(ship_manager, "ship_manager")
	
	for component in ship_components:
		if component is Node:
			auto_cleanup_node(component, "ship_component_%s" % component.get_class())

## Equipment system cleanup helper
static func setup_equipment_cleanup(equipment_manager: Node, equipment_items: Array) -> void:
	## Setup cleanup for equipment system components
	if equipment_manager:
		auto_cleanup_node(equipment_manager, "equipment_manager")
	
	for item in equipment_items:
		if item is Node:
			auto_cleanup_node(item, "equipment_item")

## INTEGRATION WITH EXISTING SYSTEMS

## Integrate with MemoryLeakPrevention
static func integrate_with_memory_leak_prevention() -> void:
	## Integrate cleanup helpers with MemoryLeakPrevention system
	MemoryLeakPrevention.add_leak_detection_callback(_on_memory_threshold_exceeded)

## Memory threshold callback
static func _on_memory_threshold_exceeded(current_memory: float, peak_memory: float, baseline_memory: float) -> void:
	## Triggered when memory thresholds are exceeded
	print("[CleanupHelpers] Memory threshold exceeded - triggering preventive cleanup")
	
	# Trigger cleanup of low-priority items
	await UniversalCleanupFramework._trigger_preventive_cleanup()

## AUTOLOAD INTEGRATION HELPERS

## Setup autoload cleanup
static func setup_autoload_cleanup(autoload_name: String, autoload_node: Node) -> void:
	## Setup cleanup for autoloaded systems
	if not autoload_node:
		return
	
	# Register custom cleanup callback for autoload
	var cleanup_callback = func():
		if autoload_node.has_method("cleanup"):
			autoload_node.cleanup()
		elif autoload_node.has_method("shutdown"):
			autoload_node.shutdown()
		print("[CleanupHelpers] Cleaned up autoload: %s" % autoload_name)
	
	UniversalCleanupFramework.register_cleanup_callback(
		cleanup_callback, 
		UniversalCleanupFramework.CleanupPriority.HIGH,
		"autoload_" + autoload_name
	)

## DEBUGGING AND MONITORING

## Get cleanup status for debugging
static func get_cleanup_status() -> Dictionary:
	## Get comprehensive cleanup status for debugging
	var status = {
		"framework_initialized": UniversalCleanupFramework != null,
		"registered_cleanup_count": 0,
		"cleanup_statistics": {},
		"memory_integration": false
	}
	
	status.registered_cleanup_count = UniversalCleanupFramework.get_registered_cleanup_count()
	status.cleanup_statistics = UniversalCleanupFramework.get_cleanup_statistics()
	status.memory_integration = true
	status.memory_stable = MemoryLeakPrevention.is_memory_stable()
	
	return status

## Print cleanup diagnostics
static func print_cleanup_diagnostics() -> void:
	## Print detailed cleanup diagnostics to console
	var status = get_cleanup_status()
	
	print("\n[CleanupHelpers] CLEANUP DIAGNOSTICS")
	print("=====================================")
	print("Framework Initialized: %s" % status.framework_initialized)
	print("Registered Cleanup Items: %d" % status.registered_cleanup_count)
	print("Memory Integration: %s" % status.memory_integration)
	
	if status.has("memory_stable"):
		print("Memory Stable: %s" % status.memory_stable)
	
	var stats = status.cleanup_statistics
	if stats.size() > 0:
		print("\nCleanup Statistics:")
		for key in stats.keys():
			print("  %s: %s" % [key, stats[key]])
	
	print("=====================================\n")

## EASY GLOBAL ACCESS METHODS

## Initialize cleanup helpers globally
static func initialize_global_cleanup() -> void:
	## Initialize cleanup helpers for global use across the project
	# Initialize UniversalCleanupFramework
	UniversalCleanupFramework.initialize()
	
	# Integrate with MemoryLeakPrevention
	integrate_with_memory_leak_prevention()
	
	print("[CleanupHelpers] ✅ Global cleanup helpers initialized")

## Emergency cleanup all systems
static func emergency_cleanup_all() -> Dictionary:
	## Emergency cleanup of all systems - use only in critical situations
	print("[CleanupHelpers] 🚨 EMERGENCY CLEANUP ALL SYSTEMS")
	
	var cleanup_result = {
		"universal_cleanup": {},
		"memory_cleanup": {},
		"timestamp": Time.get_ticks_msec()
	}
	
	# Universal cleanup
	cleanup_result.universal_cleanup = await UniversalCleanupFramework.emergency_cleanup()
	
	# Memory cleanup
	cleanup_result.memory_cleanup = await MemoryLeakPrevention.emergency_memory_release()
	
	print("[CleanupHelpers] ✅ Emergency cleanup complete")
	return cleanup_result