class_name GdUnitBaseTest
extends GdUnitTestSuite

## Base test class for gdUnit4 framework
## Provides common testing utilities and resource management

# Resource tracking for automatic cleanup
var _tracked_nodes: Array[Node] = []
var _tracked_resources: Array[Resource] = []

## Lifecycle methods for gdUnit4
func before():
	"""Setup run once before all tests"""
	pass

func after():
	"""Cleanup run once after all tests"""
	_cleanup_all_resources()

func before_test():
	"""Setup run before each test"""
	_reset_tracking()

func after_test():
	"""Cleanup run after each test"""
	_cleanup_test_resources()

## Resource Management
func track_node(node: Node) -> Node:
	"""Track a node for automatic cleanup"""
	if node and is_instance_valid(node):
		_tracked_nodes.append(node)
	return node

func track_resource(resource: Resource) -> Resource:
	"""Track a resource for automatic cleanup"""
	if resource and is_instance_valid(resource):
		_tracked_resources.append(resource)
	return resource

func _reset_tracking():
	"""Reset resource tracking arrays"""
	_tracked_nodes.clear()
	_tracked_resources.clear()

func _cleanup_test_resources():
	"""Clean up resources tracked for this test"""
	# Clean up tracked nodes
	for node in _tracked_nodes:
		if is_instance_valid(node):
			if node.get_parent():
				node.get_parent().remove_child(node)
			node.queue_free()
	
	# Clean up tracked resources
	for resource in _tracked_resources:
		if is_instance_valid(resource):
			resource = null
	
	_reset_tracking()

func _cleanup_all_resources():
	"""Final cleanup of all resources"""
	_cleanup_test_resources()

## Engine stabilization utility
func stabilize_engine(wait_time: float = 0.1) -> void:
	"""Wait for engine to stabilize"""
	await get_tree().create_timer(wait_time).timeout

## Performance measurement utility
func measure_performance(callable: Callable, iterations: int = 100) -> Dictionary:
	"""Measure performance of a callable function"""
	var start_time = Time.get_ticks_msec()
	
	for i in range(iterations):
		callable.call()
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	return {
		"duration_ms": duration,
		"iterations": iterations,
		"avg_per_iteration_ms": float(duration) / iterations
	}
