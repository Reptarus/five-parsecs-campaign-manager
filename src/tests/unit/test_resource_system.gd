class_name TestResourceSystem
extends "res://addons/gut/test.gd"

const ResourceSystem = preload("res://src/core/systems/ResourceSystem.gd")

var resource_system: ResourceSystem
var test_resource_path = "res://src/core/systems/GlobalEnums.gd" # Using an existing resource for testing

func before_each():
	resource_system = ResourceSystem.new()
	add_child_autoqfree(resource_system)

func after_each():
	resource_system = null

func test_load_resource():
	var signal_emitted = false
	resource_system.resource_loaded.connect(
		func(path): signal_emitted = true
	)
	
	var resource = resource_system.load_resource(test_resource_path)
	assert_not_null(resource,
		"Resource should be loaded successfully")
	assert_true(signal_emitted,
		"Resource loaded signal should be emitted")

func test_load_invalid_resource():
	var signal_emitted = false
	resource_system.resource_failed_to_load.connect(
		func(path): signal_emitted = true
	)
	
	var resource = resource_system.load_resource("res://invalid/path.tres")
	assert_null(resource,
		"Invalid resource should return null")
	assert_true(signal_emitted,
		"Resource failed to load signal should be emitted")

func test_resource_caching():
	# Load resource first time
	var resource1 = resource_system.load_resource(test_resource_path)
	
	# Load same resource again
	var signal_emitted = false
	resource_system.resource_loaded.connect(
		func(path): signal_emitted = true
	)
	
	var resource2 = resource_system.load_resource(test_resource_path)
	assert_eq(resource1, resource2,
		"Cached resource should be returned")
	assert_false(signal_emitted,
		"Resource loaded signal should not be emitted for cached resources")

func test_queue_resource():
	resource_system.queue_resource(test_resource_path)
	assert_true(resource_system._is_loading,
		"Resource system should be in loading state")
	assert_has(resource_system._resource_queue, test_resource_path,
		"Resource path should be in queue")

func test_queue_duplicate_resource():
	resource_system.queue_resource(test_resource_path)
	resource_system.queue_resource(test_resource_path)
	
	var queue_count = resource_system._resource_queue.count(test_resource_path)
	assert_eq(queue_count, 1,
		"Duplicate resource should not be added to queue")

func test_unload_resource():
	# Load resource first
	var resource = resource_system.load_resource(test_resource_path)
	assert_not_null(resource,
		"Resource should be loaded")
	
	# Unload resource
	resource_system.unload_resource(test_resource_path)
	assert_false(resource_system._loaded_resources.has(test_resource_path),
		"Resource should be unloaded")

func test_clear_resources():
	# Load and queue some resources
	resource_system.load_resource(test_resource_path)
	resource_system.queue_resource("res://some/other/path.tres")
	
	resource_system.clear_resources()
	assert_eq(resource_system._loaded_resources.size(), 0,
		"Loaded resources should be cleared")
	assert_eq(resource_system._resource_queue.size(), 0,
		"Resource queue should be cleared")
	assert_false(resource_system._is_loading,
		"Loading state should be reset")

func test_process_queue():
	resource_system.queue_resource(test_resource_path)
	
	# Simulate process frame
	resource_system._process(0.0)
	
	assert_eq(resource_system._resource_queue.size(), 0,
		"Resource queue should be empty after processing")
	assert_true(resource_system._loaded_resources.has(test_resource_path),
		"Resource should be loaded after processing queue")
