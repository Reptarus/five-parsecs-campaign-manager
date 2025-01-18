@tool
extends "res://tests/test_base.gd"

const ResourceSystem := preload("res://src/core/systems/ResourceSystem.gd")
const TestHelper := preload("res://tests/fixtures/test_helper.gd")

var system: Node
var test_resource_path := "res://src/core/systems/GlobalEnums.gd" # Using an existing resource for testing

func before_each() -> void:
    super.before_each()
    system = ResourceSystem.new()
    add_child(system)

func after_each() -> void:
    super.after_each()
    system = null

func test_load_resource() -> void:
    var signal_emitted := false
    system.resource_loaded.connect(
        func(path): signal_emitted = true
    )
    
    var resource = system.load_resource(test_resource_path)
    assert_not_null(resource, "Resource should be loaded successfully")
    assert_true(signal_emitted, "Resource loaded signal should be emitted")

func test_load_invalid_resource() -> void:
    var signal_emitted := false
    system.resource_failed_to_load.connect(
        func(path): signal_emitted = true
    )
    
    var resource = system.load_resource("res://invalid/path.tres")
    assert_null(resource, "Invalid resource should return null")
    assert_true(signal_emitted, "Resource failed to load signal should be emitted")

func test_resource_caching() -> void:
    # Load resource first time
    var resource1 = system.load_resource(test_resource_path)
    
    # Load same resource again
    var signal_emitted := false
    system.resource_loaded.connect(
        func(path): signal_emitted = true
    )
    
    var resource2 = system.load_resource(test_resource_path)
    assert_eq(resource1, resource2, "Cached resource should be returned")
    assert_false(signal_emitted, "Resource loaded signal should not be emitted for cached resources")

func test_queue_resource() -> void:
    system.queue_resource(test_resource_path)
    assert_true(system._is_loading, "Resource system should be in loading state")
    assert_true(system._resource_queue.has(test_resource_path), "Resource path should be in queue")

func test_queue_duplicate_resource() -> void:
    system.queue_resource(test_resource_path)
    system.queue_resource(test_resource_path)
    
    var queue_count: int = system._resource_queue.count(test_resource_path)
    assert_eq(queue_count, 1, "Duplicate resource should not be added to queue")

func test_unload_resource() -> void:
    # Load resource first
    var resource = system.load_resource(test_resource_path)
    assert_not_null(resource, "Resource should be loaded")
    
    # Unload resource
    system.unload_resource(test_resource_path)
    assert_false(system._loaded_resources.has(test_resource_path), "Resource should be unloaded")

func test_clear_resources() -> void:
    # Load and queue some resources
    system.load_resource(test_resource_path)
    system.queue_resource("res://some/other/path.tres")
    
    system.clear_resources()
    assert_eq(system._loaded_resources.size(), 0, "Loaded resources should be cleared")
    assert_eq(system._resource_queue.size(), 0, "Resource queue should be cleared")
    assert_false(system._is_loading, "Loading state should be reset")

func test_process_queue() -> void:
    system.queue_resource(test_resource_path)
    
    # Simulate process frame
    system._process(0.0)
    
    assert_eq(system._resource_queue.size(), 0, "Resource queue should be empty after processing")
    assert_true(system._loaded_resources.has(test_resource_path), "Resource should be loaded after processing queue")