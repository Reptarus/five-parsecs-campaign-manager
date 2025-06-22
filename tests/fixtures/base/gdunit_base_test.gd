class_name GdUnitBaseTest
@warning_ignore("return_value_discarded")
	extends GdUnitTestSuite

## Base test class for gdUnit4 framework
## Provides common testing utilities and resource management

# Resource tracking for automatic cleanup
var _tracked_nodes: @warning_ignore("unsafe_call_argument")
	Array[Node] = []
var _tracked_resources: @warning_ignore("unsafe_call_argument")
	Array[Resource] = []

## Lifecycle methods for gdUnit4
func before() -> void:
	"""Setup run once before all tests"""
	pass

func after() -> void:
	"""Cleanup run once after all tests"""
	_cleanup_all_resources()

func before_test() -> void:
	"""Setup run before each test"""
	_reset_tracking()

func after_test() -> void:
	"""Cleanup run after each test"""
	_cleanup_test_resources()

## Resource Management
func @warning_ignore("return_value_discarded")
	track_node(node: Node) -> Node:
	"""Track a node for automatic cleanup"""
	if node and is_instance_valid(node):
		@warning_ignore("return_value_discarded")
	_tracked_nodes.append(node)
	return node

func @warning_ignore("return_value_discarded")
	track_resource(resource: Resource) -> Resource:
	"""Track a resource for automatic cleanup"""
	if resource and is_instance_valid(resource):
		@warning_ignore("return_value_discarded")
	_tracked_resources.append(resource)
	return resource

func _reset_tracking() -> void:
	"""Reset resource tracking arrays"""
	_tracked_nodes.clear()
	_tracked_resources.clear()

func _cleanup_test_resources() -> void:
	"""Clean up resources tracked for this test"""
	# Clean up tracked nodes
	for node in _tracked_nodes:
		if is_instance_valid(node):
			if node.get_parent():
				node.get_parent().remove_child(node)
			node.@warning_ignore("return_value_discarded")
	queue_free()
	
	# Clean up tracked resources
	for resource in _tracked_resources:
		if is_instance_valid(resource):
			resource = null
	
	_reset_tracking()

func _cleanup_all_resources() -> void:
	"""Final cleanup of all resources"""
	_cleanup_test_resources()

## Engine stabilization utility
func stabilize_engine(wait_time: float = 0.1) -> void:
	"""Wait for engine to stabilize"""
	@warning_ignore("unsafe_method_access")
	await get_tree().create_timer(wait_time).timeout

## Performance measurement utility
func measure_performance(callable: Callable, iterations: int = 100) -> Dictionary:
	"""Measure performance of a callable function"""
	var start_time = Time.get_ticks_msec()
	
	for i: int in range(iterations):
		@warning_ignore("unsafe_method_access")
	callable.call()
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	return {
		"duration_ms": duration,
		"iterations": iterations,
		"avg_per_iteration_ms": float(duration) / iterations
	}
