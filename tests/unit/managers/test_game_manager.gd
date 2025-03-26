## Game Manager Test Suite
## Tests the functionality of the GameManager class which orchestrates game systems 
## and core functionality.
##
## This test suite verifies:
## - Proper initialization and cleanup
## - System registration and management
## - Game state transitions
## - Cross-system communication
## - Resource management
@tool
extends "res://tests/fixtures/base/game_test.gd"

# Load scripts safely - handles missing files gracefully
var GameManagerScript = load("res://src/core/managers/base/GameManager.gd") if ResourceLoader.exists("res://src/core/managers/base/GameManager.gd") else load("res://src/core/managers/GameManager.gd") if ResourceLoader.exists("res://src/core/managers/GameManager.gd") else null
var GameSystemScript = load("res://src/core/systems/base/GameSystem.gd") if ResourceLoader.exists("res://src/core/systems/base/GameSystem.gd") else load("res://src/core/systems/GameSystem.gd") if ResourceLoader.exists("res://src/core/systems/GameSystem.gd") else null
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")

# Test systems for registration
class TestSystem:
	extends RefCounted
	var initialized: bool = false
	var updated: bool = false
	var cleaned_up: bool = false
	var update_delta: float = 0.0
	
	func _init() -> void:
		# Fix: Cannot directly set resource_path, use a valid path when needed
		pass
	
	func initialize() -> bool:
		initialized = true
		return true
		
	func update(delta: float) -> void:
		updated = true
		update_delta = delta
		
	func cleanup() -> void:
		cleaned_up = true

# Type-safe instance variables
var _manager: Node
var _test_system: RefCounted

func before_each() -> void:
	await super.before_each()
	
	# Create manager
	if not GameManagerScript:
		push_error("GameManager script not found")
		return
		
	_manager = GameManagerScript.new()
	if not _manager:
		push_error("Failed to create game manager")
		return
		
	add_child_autofree(_manager)
	track_test_node(_manager)
	
	# Create test system
	_test_system = TestSystem.new()
	if not _test_system:
		push_error("Failed to create test system")
		return
		
	_test_system = Compatibility.ensure_resource_path(_test_system, "test_system")
	
	watch_signals(_manager)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_manager = null
	_test_system = null
	await super.after_each()

# Registration tests
func test_register_system() -> void:
	var result: bool = Compatibility.safe_call_method(_manager, "register_system", ["test", _test_system], false)
	assert_true(result, "Should register system successfully")
	
	var has_system: bool = Compatibility.safe_call_method(_manager, "has_system", ["test"], false)
	assert_true(has_system, "Should have registered system")
	
	var same_system = Compatibility.safe_call_method(_manager, "get_system", ["test"], null)
	assert_eq(same_system, _test_system, "Should retrieve the same system instance")

# System lifecycle tests
func test_initialize_systems() -> void:
	Compatibility.safe_call_method(_manager, "register_system", ["test", _test_system])
	var result: bool = Compatibility.safe_call_method(_manager, "initialize", [], false)
	assert_true(result, "Should initialize successfully")
	assert_true(_test_system.initialized, "Test system should be initialized")

func test_update_systems() -> void:
	Compatibility.safe_call_method(_manager, "register_system", ["test", _test_system])
	Compatibility.safe_call_method(_manager, "initialize", [])
	
	var test_delta: float = 0.16
	Compatibility.safe_call_method(_manager, "update", [test_delta])
	
	assert_true(_test_system.updated, "Test system should be updated")
	assert_eq(_test_system.update_delta, test_delta, "Delta time should be passed correctly")

func test_cleanup_systems() -> void:
	Compatibility.safe_call_method(_manager, "register_system", ["test", _test_system])
	Compatibility.safe_call_method(_manager, "initialize", [])
	Compatibility.safe_call_method(_manager, "cleanup", [])
	
	assert_true(_test_system.cleaned_up, "Test system should be cleaned up")

# Error handling tests
func test_register_null_system() -> void:
	var result: bool = Compatibility.safe_call_method(_manager, "register_system", ["null_test", null], false)
	assert_false(result, "Should reject null system")

func test_register_duplicate_system() -> void:
	Compatibility.safe_call_method(_manager, "register_system", ["test", _test_system])
	
	var duplicate_system = TestSystem.new()
	duplicate_system = Compatibility.ensure_resource_path(duplicate_system, "duplicate_system")
	
	var result: bool = Compatibility.safe_call_method(_manager, "register_system", ["test", duplicate_system], true)
	assert_false(result, "Should reject duplicate system name")

func test_unregister_system() -> void:
	Compatibility.safe_call_method(_manager, "register_system", ["test", _test_system])
	var result: bool = Compatibility.safe_call_method(_manager, "unregister_system", ["test"], false)
	assert_true(result, "Should unregister successfully")
	
	var has_system: bool = Compatibility.safe_call_method(_manager, "has_system", ["test"], true)
	assert_false(has_system, "Should no longer have system")

# Performance test
func test_system_update_performance() -> void:
	var system_count: int = 20
	var systems: Array = []
	
	for i in range(system_count):
		var system = TestSystem.new()
		system = Compatibility.ensure_resource_path(system, "system_%d" % i)
		Compatibility.safe_call_method(_manager, "register_system", ["test_%d" % i, system])
		systems.append(system)
	
	Compatibility.safe_call_method(_manager, "initialize", [])
	
	var start_time := Time.get_ticks_msec()
	for i in range(60): # Simulate 1 second at 60 fps
		Compatibility.safe_call_method(_manager, "update", [0.016667])
	var end_time := Time.get_ticks_msec()
	var duration := end_time - start_time
	
	for system in systems:
		assert_true(system.updated, "All systems should be updated")
	
	# 100ms is a reasonable threshold for updating 20 systems 60 times
	assert_true(duration < 100, "System updates should be performant")

# Signal verification test
func test_system_signals() -> void:
	watch_signals(_manager)
	
	Compatibility.safe_call_method(_manager, "register_system", ["test", _test_system])
	verify_signal_emitted(_manager, "system_registered")
	
	Compatibility.safe_call_method(_manager, "initialize", [])
	verify_signal_emitted(_manager, "systems_initialized")
	
	Compatibility.safe_call_method(_manager, "unregister_system", ["test"])
	verify_signal_emitted(_manager, "system_unregistered")