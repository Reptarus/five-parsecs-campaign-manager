@tool
extends "res://tests/fixtures/base_test.gd"

const ResourceSystem := preload("res://src/core/systems/ResourceSystem.gd")

# Test variables
var system: Node
var test_resource_path := "res://src/core/systems/GlobalEnums.gd"

func before_each() -> void:
	await super.before_each()
	system = ResourceSystem.new()
	add_child(system)
	track_test_node(system)

func after_each() -> void:
	await super.after_each()
	system = null

func test_load_resource() -> void:
	var resource = system.load_resource(test_resource_path)
	assert_not_null(resource, "Resource should be loaded successfully")
	assert_signal_emitted(system, "resource_loaded")

func test_load_invalid_resource() -> void:
	var resource = system.load_resource("res://invalid/path.tres")
	assert_null(resource, "Invalid resource should return null")
	assert_signal_emitted(system, "resource_failed_to_load")

func test_resource_caching() -> void:
	var resource1 = system.load_resource(test_resource_path)
	var resource2 = system.load_resource(test_resource_path)
	assert_eq(resource1, resource2, "Cached resource should be returned")
	assert_signal_not_emitted(system, "resource_loaded")

func test_queue_resource() -> void:
	system.queue_resource(test_resource_path)
	assert_true(system._is_loading, "Resource system should be in loading state")
	assert_true(system._resource_queue.has(test_resource_path), "Resource path should be in queue")
